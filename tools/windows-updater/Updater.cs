using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using System.Text;
using System.Threading;
using Microsoft.Win32;

namespace OneMoreTry.Update
{
    [DataContract] public sealed class Manifest
    {
        [DataMember(Name="schema")] public int Schema;
        [DataMember(Name="version")] public string Version;
        [DataMember(Name="channel")] public string Channel;
    }
    [DataContract] public sealed class Handoff
    {
        [DataMember(Name="install_dir")] public string InstallDir;
        [DataMember(Name="package_path")] public string PackagePath;
        [DataMember(Name="current_version")] public string CurrentVersion;
        [DataMember(Name="version")] public string Version;
        [DataMember(Name="channel")] public string Channel;
        [DataMember(Name="sha256")] public string Sha256;
        [DataMember(Name="size")] public long Size;
        [DataMember(Name="parent_pid")] public int ParentPid;
        [DataMember(Name="restart_arguments")] public string[] RestartArguments;
    }
    [DataContract] public sealed class Receipt
    {
        [DataMember(Name="success")] public bool Success;
        [DataMember(Name="version")] public string Version;
        [DataMember(Name="error")] public string Error;
    }
    public static class Json
    {
        public static T Read<T>(string file)
        {
            using (var stream = File.OpenRead(file))
                return (T)new DataContractJsonSerializer(typeof(T)).ReadObject(stream);
        }
        public static void Write<T>(string file, T data)
        {
            using (var stream = File.Create(file))
                new DataContractJsonSerializer(typeof(T)).WriteObject(stream, data);
        }
    }
    public static class Patcher
    {
        public const string Game = "OneMoreTry.exe";
        public const string Helper = "OneMoreTry.Update.exe";
        public const string ManifestFile = "update-manifest.json";
        const long MaxBytes = 512L * 1024 * 1024;
        static readonly HashSet<string> Allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        { Game, Helper, ManifestFile, "README.txt", "licenses/Godot.txt", "licenses/Godot-third-party.txt", "licenses/NotoSansCJK.txt" };

        public static string Hash(Stream stream)
        {
            using (var hash = SHA256.Create())
                return BitConverter.ToString(hash.ComputeHash(stream)).Replace("-", "").ToLowerInvariant();
        }
        public static int Compare(string a, string b)
        {
            var regex = new Regex(@"^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})(-beta)?$");
            var x = regex.Match(a ?? ""); var y = regex.Match(b ?? "");
            if (!x.Success || !y.Success) throw new InvalidDataException("Invalid version");
            for (int n = 1; n <= 3; n++)
            {
                int cmp = int.Parse(x.Groups[n].Value).CompareTo(int.Parse(y.Groups[n].Value));
                if (cmp != 0) return cmp;
            }
            return (x.Groups[4].Success ? 0 : 1).CompareTo(y.Groups[4].Success ? 0 : 1);
        }
        public static string ValidateName(string name)
        {
            // Exact shipped-file allowlist, including case-insensitive duplicates.
            // No archive entry can target records, settings, shortcuts or uninstaller.
            name = name.Replace('\\','/');
            if (name.StartsWith("./", StringComparison.Ordinal)) name = name.Substring(2);
            if (!Allowed.Contains(name) || name.Contains(":"))
                throw new InvalidDataException("Unexpected package entry: " + name);
            return name;
        }
        static void PlainPath(string path)
        {
            for (var dir = new DirectoryInfo(path); dir != null; dir = dir.Parent)
                if (dir.Exists && (dir.Attributes & FileAttributes.ReparsePoint) != 0)
                    throw new InvalidDataException("Linked update path");
        }
        public static List<string> Stage(Handoff job, string stage)
        {
            if (job.Size < 1 || job.Size > MaxBytes || !Regex.IsMatch(job.Sha256 ?? "", "^[a-f0-9]{64}$"))
                throw new InvalidDataException("Invalid package identity");
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            Directory.CreateDirectory(stage);
            using (var file = new FileStream(job.PackagePath, FileMode.Open, FileAccess.Read, FileShare.Read))
            {
                if (file.Length != job.Size || Hash(file) != job.Sha256)
                    throw new InvalidDataException("Package checksum mismatch");
                file.Position = 0;
                using (var zip = new ZipArchive(file, ZipArchiveMode.Read))
                {
                    if (zip.Entries.Count > 16) throw new InvalidDataException("Too many package entries");
                    long expanded = 0;
                    foreach (var entry in zip.Entries)
                    {
                        string directoryName = entry.FullName.Replace('\\','/');
                        if (directoryName == "licenses/" || directoryName == "./licenses/") continue;
                        string name = ValidateName(entry.FullName);
                        if (!seen.Add(name) || ((entry.ExternalAttributes >> 16) & 0xF000) == 0xA000 ||
                            (entry.ExternalAttributes & (int)FileAttributes.ReparsePoint) != 0)
                            throw new InvalidDataException("Duplicate or linked package entry");
                        expanded = checked(expanded + entry.Length);
                        if (entry.Length < 1 || expanded > MaxBytes) throw new InvalidDataException("Package too large");
                        if (name == ManifestFile && entry.Length > 65536) throw new InvalidDataException("Manifest too large");
                        string target = Path.Combine(stage, name.Replace('/', Path.DirectorySeparatorChar));
                        Directory.CreateDirectory(Path.GetDirectoryName(target));
                        using (var input = entry.Open())
                        using (var output = File.Create(target))
                        {
                            var buffer = new byte[65536]; long count = 0; int read;
                            while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
                            {
                                count += read;
                                if (count > entry.Length || count > MaxBytes) throw new InvalidDataException("Expanded size mismatch");
                                output.Write(buffer, 0, read);
                            }
                            if (count != entry.Length) throw new InvalidDataException("Truncated package");
                        }
                    }
                }
            }
            if (!seen.Contains(Game) || !seen.Contains(Helper) || !seen.Contains(ManifestFile))
                throw new InvalidDataException("Incomplete update package");
            var manifest = Json.Read<Manifest>(Path.Combine(stage, ManifestFile));
            if (manifest.Schema != 1 || manifest.Version != job.Version || manifest.Channel != job.Channel ||
                (manifest.Channel != "stable" && manifest.Channel != "beta") ||
                manifest.Version.EndsWith("-beta", StringComparison.Ordinal) != (manifest.Channel == "beta"))
                throw new InvalidDataException("Package version or channel mismatch");
            // Install the self-contained game last. Its embedded resources move together.
            return seen.OrderBy(x => x == Game ? 1 : 0).ThenBy(x => x).ToList();
        }
        public static void Apply(Handoff job, Action waitForParent, Action restart)
        {
            job.InstallDir = Path.GetFullPath(job.InstallDir);
            PlainPath(job.InstallDir);
            if (!File.Exists(Path.Combine(job.InstallDir, Game))) throw new InvalidDataException("Missing installed game");
            using (var installLock = new FileStream(Path.Combine(job.InstallDir, ".update.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None))
            {
                var current = Json.Read<Manifest>(Path.Combine(job.InstallDir, ManifestFile));
                if (current.Schema != 1 || current.Version != job.CurrentVersion || Compare(job.Version, current.Version) <= 0)
                    throw new InvalidDataException("Installed version changed or downgrade requested");
                string work = Path.Combine(job.InstallDir, ".update-" + Guid.NewGuid().ToString("N"));
                string stage = Path.Combine(work, "stage"), backup = Path.Combine(work, "backup");
                var changed = new List<string>();
                bool clean = false;
                try
                {
                    var files = Stage(job, stage);
                    waitForParent();
                    foreach (string name in files)
                    {
                        string relative = name.Replace('/', Path.DirectorySeparatorChar);
                        string target = Path.Combine(job.InstallDir, relative), old = Path.Combine(backup, relative);
                        PlainPath(Path.GetDirectoryName(target));
                        if (File.Exists(target) && (File.GetAttributes(target) & FileAttributes.ReparsePoint) != 0)
                            throw new InvalidDataException("Linked target file");
                        Directory.CreateDirectory(Path.GetDirectoryName(target));
                        Directory.CreateDirectory(Path.GetDirectoryName(old));
                        if (File.Exists(target)) File.Replace(Path.Combine(stage, relative), target, old);
                        else File.Move(Path.Combine(stage, relative), target);
                        changed.Add(name);
                    }
                    restart();
                    clean = true;
                }
                catch
                {
                    changed.Reverse();
                    foreach (string name in changed)
                    {
                        string target = Path.Combine(job.InstallDir, name), old = Path.Combine(backup, name);
                        if (File.Exists(old) && File.Exists(target)) File.Replace(old, target, null);
                        else if (File.Exists(old)) File.Move(old, target);
                        else if (File.Exists(target)) File.Delete(target);
                    }
                    clean = true;
                    throw;
                }
                finally
                {
                    if (clean && Directory.Exists(work))
                        try { Directory.Delete(work, true); } catch { /* Retain leftovers; the committed game remains valid. */ }
                }
            }
        }
        public static void WaitForParent(Handoff job)
        {
            if (job.ParentPid <= 0) throw new InvalidDataException("Missing parent process");
            Process parent;
            try { parent = Process.GetProcessById(job.ParentPid); }
            catch (ArgumentException) { return; }
            using (parent)
            {
                try
                {
                    if (!string.Equals(Path.GetFullPath(parent.MainModule.FileName), Path.Combine(job.InstallDir, Game), StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException("Parent is not the installed game");
                }
                catch (InvalidOperationException) { return; }
                catch (System.ComponentModel.Win32Exception) { if (parent.HasExited) return; throw; }
                if (!parent.WaitForExit(45000)) throw new IOException("Game is still running");
            }
        }
        public static string Quote(string value)
        {
            var result = new StringBuilder("\""); int slashes = 0;
            foreach (char c in value)
            {
                if (c == '\\') { slashes++; continue; }
                result.Append('\\', c == '"' ? slashes * 2 + 1 : slashes);
                result.Append(c); slashes = 0;
            }
            return result.Append('\\', slashes * 2).Append('"').ToString();
        }
        public static void Restart(Handoff job, string cache, string expectedVersion)
        {
            string token = Guid.NewGuid().ToString("N");
            string ready = Path.Combine(cache, "ready-" + token);
            var arguments = new List<string>(job.RestartArguments ?? new string[0]);
            if (!arguments.Contains("--")) arguments.Add("--");
            arguments.Add("--update-ready-token=" + token);
            var process = Process.Start(new ProcessStartInfo(Path.Combine(job.InstallDir, Game), string.Join(" ", arguments.Select(Quote)))
            { UseShellExecute = false, WorkingDirectory = job.InstallDir });
            if (process == null) throw new IOException("Cannot restart game");
            using (process)
            {
                var watch = Stopwatch.StartNew();
                while (watch.ElapsedMilliseconds < 20000)
                {
                    if (File.Exists(ready) && File.ReadAllText(ready).Trim() == expectedVersion)
                    { File.Delete(ready); return; }
                    if (process.HasExited) throw new IOException("Updated game exited before startup completed");
                    Thread.Sleep(100);
                }
                process.Kill(); process.WaitForExit(5000);
                throw new IOException("Updated game did not finish startup");
            }
        }
    }
    public static class Program
    {
        static void UpdateInstalledVersion(Handoff job)
        {
            try
            {
                using (var registry = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry64))
                using (var app = registry.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\{8B5C1547-21FA-47B4-B183-B0CF8AA2F502}_is1", true))
                    if (app != null && string.Equals(Convert.ToString(app.GetValue("InstallLocation")).TrimEnd('\\'),job.InstallDir.TrimEnd('\\'),StringComparison.OrdinalIgnoreCase))
                        app.SetValue("DisplayVersion",job.Version);
            }
            catch { /* Portable copies and restricted registry access do not block a committed update. */ }
        }
        [STAThread] public static int Main(string[] args)
        {
            if (args.Length != 1) return 2;
            string handoff = Path.GetFullPath(args[0]);
            string receipt = Path.Combine(Path.GetDirectoryName(Path.GetDirectoryName(handoff)), "apply-result.json");
            Handoff job = null;
            try
            {
                job = Json.Read<Handoff>(handoff);
                Patcher.Apply(job, () => Patcher.WaitForParent(job), () =>
                {
                    Json.Write(receipt, new Receipt { Success = true, Version = job.Version });
                    Patcher.Restart(job, Path.GetDirectoryName(receipt), job.Version);
                });
                UpdateInstalledVersion(job);
                return 0;
            }
            catch (Exception error)
            {
                try { Json.Write(receipt, new Receipt { Success = false, Version = job == null ? "" : job.Version, Error = error.ToString() }); }
                catch { /* A full cache volume must not prevent restarting the intact game. */ }
                if (job != null)
                    try
                    {
                        Patcher.WaitForParent(job);
                        var installed = Json.Read<Manifest>(Path.Combine(job.InstallDir,Patcher.ManifestFile));
                        Patcher.Restart(job, Path.GetDirectoryName(receipt), installed.Version);
                    }
                    catch { /* Receipt remains for the next launch. */ }
                return 1;
            }
        }
    }
}

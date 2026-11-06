using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Diagnostics;
using System.Threading;
using OneMoreTry.Update;

public static class UpdaterTests
{
    static int checks;
    static void Check(bool value, string name)
    { if (!value) throw new Exception("FAIL: " + name); checks++; Console.WriteLine("PASS: " + name); }
    static void Reject(Action action, string name)
    { bool rejected = false; try { action(); } catch { rejected = true; } Check(rejected, name); }
    static string root;
    static string WritePackage(string name, string version, string channel, Action<ZipArchive> extra = null)
    {
        string path = Path.Combine(root, name + ".zip");
        using (var file = File.Create(path))
        using (var zip = new ZipArchive(file, ZipArchiveMode.Create))
        {
            foreach (string item in new[] { Patcher.Game, Patcher.Helper })
                using (var writer = new StreamWriter(zip.CreateEntry(item).Open())) writer.Write("new " + item);
            using (var writer = new StreamWriter(zip.CreateEntry(Patcher.ManifestFile).Open()))
                writer.Write("{\"schema\":1,\"version\":\"" + version + "\",\"channel\":\"" + channel + "\"}");
            if (extra != null) extra(zip);
        }
        return path;
    }
    static Handoff Job(string package, string version = "0.6.0", string channel = "stable")
    {
        string install = Path.Combine(root, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(install);
        File.WriteAllText(Path.Combine(install, Patcher.Game), "old game");
        File.WriteAllText(Path.Combine(install, Patcher.Helper), "old helper");
        File.WriteAllText(Path.Combine(install, "records.json"), "do not touch");
        Json.Write(Path.Combine(install, Patcher.ManifestFile),new Manifest { Schema=1, Version="0.5.1", Channel="stable" });
        string hash; using (var file = File.OpenRead(package)) hash = Patcher.Hash(file);
        return new Handoff { InstallDir=install, PackagePath=package, CurrentVersion="0.5.1", Version=version, Channel=channel, Size=new FileInfo(package).Length, Sha256=hash };
    }
    static void UnitTests()
    {
        Check(Patcher.Compare("0.6.0","0.6.0-beta") > 0 && Patcher.Compare("0.5.9","0.6.0-beta") < 0, "Helper independently orders stable/beta and refuses lower-core versions");
        Reject(() => Patcher.Compare("01.2.3","0.1.0"), "Malformed helper version is rejected");
        Check(Patcher.ValidateName(@"licenses\Godot.txt") == "licenses/Godot.txt", "Windows ZIP separators normalize to the same strict file allowlist");
        foreach (string name in new[] { "../records.json", "/OneMoreTry.exe", "licenses/../OneMoreTry.exe", "C:/evil.exe", "licenses\\evil.txt", "unins000.exe", "update_settings.cfg" })
            Reject(() => Patcher.ValidateName(name), "Reject unsafe or unrelated entry " + name);
        string valid = WritePackage("valid", "0.6.0", "stable");
        var job = Job(valid); bool waited=false, restarted=false;
        Patcher.Apply(job, () => { waited=true; Check(File.ReadAllText(Path.Combine(job.InstallDir,Patcher.Game)) == "old game", "Original game remains intact until its process exits"); }, () => { restarted=true; });
        Check(waited && restarted && File.ReadAllText(Path.Combine(job.InstallDir,Patcher.Game)).StartsWith("new"), "Valid update replaces game after parent wait and restarts");
        Check(File.ReadAllText(Path.Combine(job.InstallDir,Patcher.Helper)).StartsWith("new"), "Updater itself is replaced from an independent cache process");
        Check(File.ReadAllText(Path.Combine(job.InstallDir,"records.json")) == "do not touch", "Update never changes unrelated saved data");
        job = Job(valid);
        Reject(() => Patcher.Apply(job, () => {}, () => { throw new IOException("Restart failed"); }), "Restart failure triggers rollback");
        Check(File.ReadAllText(Path.Combine(job.InstallDir,Patcher.Game)) == "old game" && File.ReadAllText(Path.Combine(job.InstallDir,Patcher.Helper)) == "old helper" && Json.Read<Manifest>(Path.Combine(job.InstallDir,Patcher.ManifestFile)).Version == "0.5.1", "Rollback restores game, helper and version together");
        job = Job(valid); job.Sha256 = new string('0',64);
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "Helper rechecks package hash before extraction");
        Check(File.ReadAllText(Path.Combine(job.InstallDir,Patcher.Game)) == "old game", "Corrupt package leaves installation intact");
        job = Job(valid); job.Size++;
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "Truncated package size is rejected");
        job = Job(valid); job.CurrentVersion = "0.5.0";
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "A changed installation cannot be overwritten by a stale handoff");
        string downgrade = WritePackage("downgrade","0.4.9","stable"); job = Job(downgrade,"0.4.9");
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "Helper refuses downgrade even with matching hash and manifest");
        job = Job(valid,"0.6.0-beta","beta");
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "Archive manifest must match selected version and channel");
        string traversal = WritePackage("traversal","0.6.0","stable", z => { using(var w=new StreamWriter(z.CreateEntry("../escape.txt").Open())) w.Write("no"); });
        job = Job(traversal);
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "ZIP traversal is rejected during real extraction");
        string duplicate = WritePackage("duplicate","0.6.0","stable", z => { using(var w=new StreamWriter(z.CreateEntry("ONEMORETRY.EXE").Open())) w.Write("no"); });
        job = Job(duplicate);
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "Case-insensitive duplicate ZIP entries are rejected");
        string mixed = WritePackage("mixed","0.6.0","stable", z => { foreach(string n in new[] { "licenses/Godot.txt", @"licenses\Godot.txt" }) using(var w=new StreamWriter(z.CreateEntry(n).Open())) w.Write("duplicate"); });
        job=Job(mixed);
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "Mixed separator aliases cannot overwrite the same staged file twice");
        string linked = WritePackage("linked","0.6.0","stable", z => { var e=z.CreateEntry("README.txt"); e.ExternalAttributes=unchecked((int)0xA1FF0000); using(var w=new StreamWriter(e.Open())) w.Write("../escape"); });
        job = Job(linked);
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "Symbolic links inside a ZIP cannot escape the stage");
        string invalid = Path.Combine(root,"invalid.zip"); File.WriteAllText(invalid,"not a zip"); job=Job(invalid);
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "Hash-valid malformed ZIP cannot replace the game");
        string incomplete = Path.Combine(root,"incomplete.zip");
        using(var f=File.Create(incomplete)) using(var z=new ZipArchive(f,ZipArchiveMode.Create))
            using(var w=new StreamWriter(z.CreateEntry(Patcher.Game).Open())) w.Write("incomplete");
        job=Job(incomplete);
        Reject(() => Patcher.Apply(job, () => {}, () => {}), "Missing updater or manifest is refused before touching installation");
        job = Job(valid);
        using (var locked = new FileStream(Path.Combine(job.InstallDir,".update.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None))
            Reject(() => Patcher.Apply(job, () => {}, () => {}), "Concurrent update transaction is refused");
        if (Environment.OSVersion.Platform == PlatformID.Win32NT)
        {
            job = Job(valid);
            using (var locked = new FileStream(Path.Combine(job.InstallDir,Patcher.Game),FileMode.Open,FileAccess.Read,FileShare.Read))
                Reject(() => Patcher.Apply(job, () => {}, () => {}), "Locked game causes transactional copy failure");
            Check(File.ReadAllText(Path.Combine(job.InstallDir,Patcher.Helper)) == "old helper", "Files replaced before a locked game are rolled back");
        }
    }
    static Process Parent(string install)
    {
        var process = Process.Start(new ProcessStartInfo(Path.Combine(install,Patcher.Game),"--headless --audio-driver Dummy --quit-after 480 -- --test") { UseShellExecute=false, WorkingDirectory=install });
        Thread.Sleep(400); return process;
    }
    static int RunHelper(string source, Handoff job, string cache)
    {
        string work = Path.Combine(cache,"apply-test-"+Guid.NewGuid().ToString("N")); Directory.CreateDirectory(work);
        File.Copy(Path.Combine(source,Patcher.Helper),Path.Combine(work,Patcher.Helper));
        Json.Write(Path.Combine(work,"handoff.json"),job);
        using(var helper = Process.Start(new ProcessStartInfo(Path.Combine(work,Patcher.Helper),Patcher.Quote(Path.Combine(work,"handoff.json"))) { UseShellExecute=false }))
        {
            if (!helper.WaitForExit(60000)) { helper.Kill(); throw new Exception("Native helper timed out"); }
            if (helper.ExitCode != 0 && File.Exists(Path.Combine(cache,"apply-result.json")))
                Console.WriteLine(File.ReadAllText(Path.Combine(cache,"apply-result.json")));
            return helper.ExitCode;
        }
    }
    static void NativeIntegration(string source)
    {
        string install = Path.Combine(root,"네이티브 설치 경로"); Directory.CreateDirectory(install);
        foreach(string file in Directory.GetFiles(source)) File.Copy(file,Path.Combine(install,Path.GetFileName(file)));
        var target = Json.Read<Manifest>(Path.Combine(source,Patcher.ManifestFile));
        Json.Write(Path.Combine(install,Patcher.ManifestFile),new Manifest { Schema=1,Version="0.5.1",Channel="stable" });
        string archive = Path.Combine(root,"native.zip"); ZipFile.CreateFromDirectory(source,archive);
        var job=Job(archive,target.Version,target.Channel); job.InstallDir=install;
        string cache=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"Godot","app_userdata","한 번만 더!","updates"); Directory.CreateDirectory(cache);
        job.RestartArguments=new[] { "--headless","--audio-driver","Dummy","--quit-after","180","--","--test" };
        using(var parent=Parent(install)) { job.ParentPid=parent.Id; Check(RunHelper(source,job,cache)==0,"Native cache helper waits for real Godot, replaces files and receives new-version startup acknowledgement"); }
        Check(Json.Read<Manifest>(Path.Combine(install,Patcher.ManifestFile)).Version==target.Version,"Native update commits the selected runtime version");
        Thread.Sleep(2200);
        string failedPayload=Path.Combine(root,"failed-payload"); Directory.CreateDirectory(failedPayload);
        foreach(string file in Directory.GetFiles(source)) File.Copy(file,Path.Combine(failedPayload,Path.GetFileName(file)));
        string next="0.6.1"+(target.Channel=="beta"?"-beta":"");
        Json.Write(Path.Combine(failedPayload,Patcher.ManifestFile),new Manifest { Schema=1,Version=next,Channel=target.Channel });
        File.Copy(Path.Combine(source,"..","Crash.exe"),Path.Combine(failedPayload,Patcher.Game),true);
        archive=Path.Combine(root,"native-crash.zip"); ZipFile.CreateFromDirectory(failedPayload,archive);
        job=Job(archive,next,target.Channel); job.InstallDir=install; job.CurrentVersion=target.Version;
        job.RestartArguments=new[] { "--headless","--audio-driver","Dummy","--quit-after","180","--","--test" };
        using(var parent=Parent(install)) { job.ParentPid=parent.Id; Check(RunHelper(source,job,cache)==1,"Native update that exits before startup is rolled back and the old game restarts"); }
        Check(Json.Read<Manifest>(Path.Combine(install,Patcher.ManifestFile)).Version==target.Version && !Json.Read<Receipt>(Path.Combine(cache,"apply-result.json")).Success,"Failed native startup restores the previous version and records a recoverable failure");
        Thread.Sleep(2200);
    }
    public static int Main(string[] args)
    {
        root=Path.Combine(Path.GetTempPath(),"OneMoreTry-updater-"+Guid.NewGuid().ToString("N")); Directory.CreateDirectory(root);
        try { UnitTests(); if(args.Length==1) NativeIntegration(Path.GetFullPath(args[0])); Console.WriteLine("Updater helper: "+checks+" checks, 0 failures"); return 0; }
        catch(Exception error) { Console.Error.WriteLine(error); return 1; }
        finally { try { Directory.Delete(root,true); } catch {} }
    }
}

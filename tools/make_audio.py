"""Original deterministic chiptune assets. No samples or third-party music."""
import array
import math
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets/audio"


def tone(freq, duration, volume=0.3, slide=0.0):
    if freq == 0:
        return [0.0] * int(duration * RATE)
    samples = []
    phase = 0.0
    for i in range(int(duration * RATE)):
        t = i / RATE
        phase += (freq + slide * t / duration) / RATE
        envelope = min(1, t / 0.006) * min(1, (duration - t) / 0.025)
        samples.append((1 if phase % 1 < 0.3 else -1) * volume * max(0, envelope))
    return samples


def save(name, samples):
    with wave.open(str(OUT / (name + ".wav")), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(array.array("h", (int(max(-1, min(1, s)) * 32767) for s in samples)).tobytes())


def sequence(notes, beat=0.12):
    return [sample for note in notes for sample in tone(note, beat)]


def main():
    OUT.mkdir(exist_ok=True, parents=True)
    melody = [76, 0, 79, 0, 81, 79, 76, 72, 74, 0, 76, 0, 79, 76, 74, 0,
              72, 0, 76, 79, 84, 0, 83, 79, 81, 79, 76, 74, 72, 0, 0, 0,
              76, 0, 79, 0, 81, 84, 83, 79, 77, 0, 81, 0, 79, 77, 76, 0,
              74, 76, 79, 0, 76, 74, 72, 69, 72, 0, 74, 0, 72, 0, 0, 0]
    song = []
    for index, note in enumerate(melody):
        lead = tone(440 * 2 ** ((note - 69) / 12), 0.18, 0.13) if note else [0.0] * int(RATE * 0.18)
        bass_note = [48, 53, 55, 48][(index // 8) % 4]
        bass = tone(440 * 2 ** ((bass_note - 69) / 12), 0.18, 0.09 if index % 2 == 0 else 0.035)
        song += [a + b for a, b in zip(lead, bass)]
    save("meadow", song)
    save("jump", tone(380, 0.12, 0.3, 390))
    save("death", tone(460, 0.13, 0.35, -270) + tone(170, 0.16, 0.3, -100))
    save("checkpoint", sequence([523, 659, 784, 1047], 0.08))
    save("crumble", tone(90, 0.08, 0.3, -40))
    save("warning", sequence([740, 0, 740], 0.055))
    save("trap", tone(130, 0.14, 0.3, 260))
    save("clear", sequence([523, 659, 784, 1047, 784, 1047, 1319, 1568], 0.13))
    save("secret", sequence([1047, 1319, 1568, 2093], 0.10))
    save("click", tone(600, 0.045, 0.2, 180))


if __name__ == "__main__":
    main()

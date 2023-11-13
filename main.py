from subprocess import Popen, PIPE
from json import loads, dump
from csv import writer
from dataclasses import dataclass
from io import StringIO
from threading import Thread
from functools import partial
from statistics import mean, median, stdev
from math import sqrt

SOLVERS = [
    "HiGHS",
    "COIN-BC",
]

RUNS = 250


@dataclass
class Statistics:
    min: int
    max: int
    mean: int
    median: int
    confidence_95: tuple[float, float]
    mean_f: float
    stdev: float


def read_all_stdout(p: Popen, strio: StringIO):
    while p.poll() is not None:
        strio.write(p.stdout.read().decode())

    strio.write(p.stdout.read().decode())


def time_run(solver: str) -> int:
    with StringIO() as strio:
        proc = Popen(
            [
                "C:\\Program Files\\MiniZinc\\minizinc.exe",
                "--json-stream",
                "--output-time",
                "--solver",
                solver,
                "stage1/mpi5-model.mzn",
                "stage1/mpi5-data-10.dzn"
            ],
            shell=False,
            stdout=PIPE
        )

        t = Thread(target=partial(read_all_stdout, proc, strio))
        t.start()
        t.join()
        strio.seek(0)
        for line in strio:
            data = loads(line)

    return int(data["time"])


def main():
    times: dict[str, list[int]] = {}
    for solver in SOLVERS:
        print("Testing", solver)
        times[solver] = [time_run(solver) for _ in range(RUNS)]

    with open("stage1-times.csv", "wt", newline="") as f:
        csv = writer(f, delimiter=",")
        csv.writerow(("solver", "time_ms"))
        for s, data in times.items():
            for datum in data:
                csv.writerow((s, datum))

    stats: dict[str, dict] = {}
    for s, data in times.items():
        data_mean = mean(data)
        data_stdev = stdev(data)
        data_stderr = data_stdev / sqrt(len(data))
        data_conf = 1.96 * data_stderr
        stats[s] = Statistics(
            min(data),
            max(data),
            int(data_mean),
            median(data),
            [data_mean - data_conf, data_mean + data_conf],
            data_mean,
            data_stdev
        ).__dict__

    with open("statistics-stage1.json", "wt") as f:
        dump(stats, f)


if __name__ == "__main__":
    main()

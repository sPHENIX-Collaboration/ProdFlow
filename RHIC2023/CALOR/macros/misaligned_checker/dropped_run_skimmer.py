#!/usr/bin/env python3

import psycopg2
import os
import sys
import argparse

db_params = {
    'dbname': 'daq',
    'user': 'phnxro',
    'host': 'db1.sphenix.bnl.gov'
}

def get_runs_with_event_mismatches(
    runtype_sel=['physics'], 
    runlist=[],
    min_run_length_sel=300,
    runnumber_min=40000, 
    runnumber_max=65000):
    
    runtype_str = ', '.join(f"%s" for _ in runtype_sel)
    params = list(runtype_sel)

    if runlist:
        run_placeholders = ', '.join(['%s'] * len(runlist))
        params.extend(runlist)
        query = f"""
            WITH valid_runs AS (
                SELECT runnumber
                FROM run
                WHERE 
                    runtype IN ({runtype_str}) AND
                    runnumber IN ({run_placeholders}) AND
                    EXTRACT(EPOCH FROM ertimestamp) - EXTRACT(EPOCH FROM brtimestamp) >= %s
            ),
            event_mismatches AS (
                SELECT runnumber, COUNT(DISTINCT nr_events) AS distinct_counts
                FROM event_numbers
                WHERE runnumber IN (SELECT runnumber FROM valid_runs)
                GROUP BY runnumber
                HAVING COUNT(DISTINCT nr_events) > 2
            )
            SELECT * FROM event_mismatches ORDER BY runnumber;
        """
        params.append(min_run_length_sel)
    else:
        query = f"""
            WITH valid_runs AS (
                SELECT runnumber
                FROM run
                WHERE 
                    runtype IN ({runtype_str}) AND
                    runnumber >= %s AND
                    runnumber <= %s AND
                    EXTRACT(EPOCH FROM ertimestamp) - EXTRACT(EPOCH FROM brtimestamp) >= %s
            ),
            event_mismatches AS (
                SELECT runnumber, COUNT(DISTINCT nr_events) AS distinct_counts
                FROM event_numbers
                WHERE runnumber IN (SELECT runnumber FROM valid_runs)
                GROUP BY runnumber
                HAVING COUNT(DISTINCT nr_events) > 2
            )
            SELECT * FROM event_mismatches ORDER BY runnumber;
        """
        params.extend([runnumber_min, runnumber_max, min_run_length_sel])

    try:
        conn = psycopg2.connect(**db_params)
        cursor = conn.cursor()
        cursor.execute(query, params)
        mismatched_runs = cursor.fetchall()
        cursor.close()
        return mismatched_runs
    except Exception as e:
        print(f"Error querying mismatched event numbers: {e}")
        return []

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Find runs with mismatched event numbers')
    parser.add_argument('-r', '--runs', type=str, help='Path to file containing runnumbers to include')
    parser.add_argument('-t', '--type', type=str, nargs='+', default=['physics'], help='Runtype to filter runs')
    parser.add_argument('--m', '--min', type=int, default=47000, help='Minimum run number to include')
    parser.add_argument('--M', '--max', type=int, default=67000, help='Maximum run number to include')
    parser.add_argument('-l', '--length', type=int, default=300, help='Minimum run length in seconds to include')                    
    parser.add_argument('-o', '--output', type=str, default='missing.txt', help='Output file to save results')
    args = parser.parse_args()

    if args.runs:
        if not os.path.isfile(args.runs):
            print(f"Runlist file '{args.runs}' not found.", file=sys.stderr)
            sys.exit(1)
        with open(args.runs, 'r') as f:
            runs = [int(line.strip()) for line in f if line.strip().isdigit()]
    else:
        runs = []

    mismatched_runs = get_runs_with_event_mismatches(
        runtype_sel=args.type,
        runlist=runs,
        min_run_length_sel=args.length,
        runnumber_min=args.m,
        runnumber_max=args.M
    )

    if not mismatched_runs:
        print("No runs with mismatched event numbers found.")
        sys.exit(0)

    runnumbers_only = [row[0] for row in mismatched_runs]

    try:
        conn = psycopg2.connect(**db_params)
        cursor = conn.cursor()

        run_placeholders = ', '.join(['%s'] * len(runnumbers_only))
        cursor.execute(f"""
            SELECT runnumber, hostname, nr_events
            FROM event_numbers
            WHERE runnumber IN ({run_placeholders})
        """, runnumbers_only)

        rows = cursor.fetchall()
        cursor.close()

        # organize into dict: run -> { host -> nr_events }
        data = {}
        for runnumber, hostname, nr_events in rows:
            if runnumber not in data:
                data[runnumber] = {}
            data[runnumber][hostname] = nr_events

        sebs = [f"seb{str(i).zfill(2)}" for i in range(21)]
        col_width = 8
        header_fmt = f"{{:<{col_width}}}{{:>{col_width}}}" + " ".join([f"{{:>{col_width}}}" for _ in sebs])
        row_fmt = f"{{:<{col_width}}}{{:>{col_width}}}" + " ".join([f"{{:>{col_width}}}" for _ in sebs])

        gl1daq_total = 0

        with open(args.output, 'w') as f_out, open("unaligned_runs.list", 'w') as f_list:
            f_out.write(header_fmt.format("run", "gl1daq", *sebs) + "\n")
            f_out.write("-" * (col_width * (len(sebs) + 2)) + "\n")

            for run in sorted(data.keys()):
                gl1 = data[run].get("gl1daq", None)
                if gl1 is None:
                    continue  # Skip if gl1daq is missing
                diffs = []
                for seb in sebs:
                    val = data[run].get(seb, "")
                    if isinstance(val, int):
                        diffs.append(val - gl1)
                    else:
                        diffs.append("")
                f_out.write(row_fmt.format(str(run), str(gl1), *diffs) + "\n")
                f_list.write(f"{run}\n")
                gl1daq_total += gl1

            f_out.write("\n")
            f_out.write(f"{'TOTAL':<{col_width}}{gl1daq_total:>{col_width}}\n")

        print(f"Wrote delta table to {args.output}")
        print("Wrote run numbers to unaligned_runs.list")
        print(f"Total gl1daq events across mismatched runs: {gl1daq_total}")


    except Exception as e:
        print(f"Error fetching event numbers: {e}")
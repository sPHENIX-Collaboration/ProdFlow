#!/usr/bin/env python3

import sys
import time
import random
from collections import defaultdict

from sphenixdbutils import cnxn_string_map, dbQuery

def main():
    if len(sys.argv) < 3:
        script_name = sys.argv[0]
        print(f"usage: {script_name} <runnumber> <daqhost>")
        sys.exit(0)

    runnumber_str = sys.argv[1]
    try:
        runnumber = int(runnumber_str)
    except ValueError:
        print(f"Error: runnumber '{runnumber_str}' must be an integer.")
        sys.exit(1)

    daqhost = sys.argv[2]

    # Using a defaultdict to easily append to lists of filenames per host
    file_list_by_host = defaultdict(list)

    # Should use parameterized query to prevent SQL injection
    sql_query = f"""
    SELECT filename, daqhost 
    FROM datasets 
    WHERE runnumber = {runnumber}
      AND (daqhost = '{daqhost}' OR daqhost = 'gl1daq') 
    ORDER BY filename
    """

    rows = dbQuery( cnxn_string_map['rawr'], sql_query).fetchall()
    for row in rows:
        filename, host = row
        file_list_by_host[host].append(filename)
        print(f"Fetched: {filename} on {host}")
        print(f"Query executed. Found {len(rows)} total file entries.")

    if not file_list_by_host:
        print("No files found for the given criteria.")
    else:
        # For debugging, similar to Perl's Dumper:
        # import pprint
        # print("Collected file lists by host:")
        # pprint.pprint(dict(file_list_by_host)) # Convert to dict for cleaner pprint
        pass

    for host, filenames in file_list_by_host.items():
        list_filename = f"{host}.list"
        print(f"Creating list file: {list_filename} with {len(filenames)} entries...")
        try:
            with open(list_filename, 'w') as f_out:
                for fname in filenames:
                    f_out.write(f"{fname}\n")
            print(f"Successfully wrote {list_filename}")
        except IOError as e:
            print(f"Error writing to file {list_filename}: {e}")

if __name__ == "__main__":
    main()

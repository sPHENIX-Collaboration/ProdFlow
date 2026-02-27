import sys
import pyodbc
import pandas as pd
import matplotlib.pyplot as plt

#####################################################################################################################
#   Usage: python3 calo_production_event_number.py <dataset tag> [start run number] [end run number]                #
#                                                                                                                   #
#   dataset tag is required (ex. ana430_2024p007)                                                                   #
#   start/end run numbers are optional if no start/end run numbers are provided all runs in the dataset are used    #
#   for use with calorimeter datasets only - does not currently query tracking DSTs
#####################################################################################################################

def get_dst_query(tag, start_run, end_run):
    query = f"SELECT runnumber, dsttype, SUM(events) FROM datasets WHERE dataset = '{tag}' AND dsttype LIKE '%DST%' "
    if start_run.strip() and end_run.strip():
        query += f"AND runnumber >= {start_run} AND runnumber <= {end_run} ";
    query += "GROUP BY runnumber, dsttype ORDER BY runnumber, dsttype;"
    return query

def get_rundb_query(start_run, end_run):
    query = f"""
    SELECT run.runnumber, run.eventsinrun 
    FROM run 
    JOIN event_numbers ON run.runnumber = event_numbers.runnumber
    WHERE run.runtype = 'physics' AND run.runnumber >= {start_run} AND run.runnumber <= {end_run} 
    AND event_numbers.hostname IN ('seb00','seb01','seb02','seb03','seb04','seb05','seb06','seb07','seb08','seb09','seb10','seb11','seb12','seb13','seb14','seb15','seb16','seb17') 
    GROUP BY run.runnumber, run.eventsinrun 
    HAVING count(DISTINCT event_numbers.hostname) = 18
    ORDER BY run.runnumber;
    """
    return query

def get_data(cursor, query):
    cursor.execute(query)
    data = [row for row in cursor.fetchall()]
    return data

def main():

    # require arguments 
    if len(sys.argv) < 2:
        print("Usage: python3 calo_production_event_number.py <dataset tag> [start run number] [end run number]")
        sys.exit(1)

    # take in arguments 
    tag = sys.argv[1]
    start_run = sys.argv[2] if len(sys.argv) > 2 else ""
    end_run = sys.argv[3] if len(sys.argv) > 3 else ""


    print("start run and end run", start_run, end_run)

    # connect to file catalog database and extract DST information
    file_catalog_conn = pyodbc.connect("DSN=FileCatalog;UID=phnxrc;READONLY=True")
    file_catalog_cursor = file_catalog_conn.cursor()
    file_catalog_query = get_dst_query(tag, start_run, end_run)
    file_catalog_data = get_data(file_catalog_cursor, file_catalog_query)
    if len(file_catalog_data) > 0: 
        print("Found entries in the File Catalog")
    file_catalog_conn.close()

    if len(file_catalog_data) > 0:
        start_run = file_catalog_data[0][0]
        end_run = file_catalog_data[-1][0]
    else:
        print("No entries found, exiting...")
        sys.exit(1)

    print("start run and end run", start_run, end_run)

    # connect to daq database and extract run information
    rundb_conn = pyodbc.connect("DSN=daq;READONLY=True")
    rundb_cursor = rundb_conn.cursor()
    rundb_query = get_rundb_query(start_run, end_run)
    rundb_data = get_data(rundb_cursor, rundb_query)
    if len(rundb_data) > 0: 
        print("Found entries in the RunDB")
    rundb_conn.close()

    # transform into dataframes and merge data
    file_catalog_data = [tuple(row) for row in file_catalog_data] 
    df1 = pd.DataFrame(file_catalog_data, columns=['runnumber', 'dsttype', 'sum_events'])
    pivot_df = df1.pivot_table(index='runnumber', columns='dsttype', values='sum_events', aggfunc='sum')
    pivot_df = pivot_df.rename(columns={
        'DST_CALOFITTING_run2pp': 'dst_calofitting',
        'DST_TRIGGERED_EVENT_run2pp': 'dst_triggered_event',
        'DST_CALO_run2pp': 'dst_calo'
    })
    pivot_df = pivot_df.reset_index()
    rundb_data = [tuple(row) for row in rundb_data] 
    df2 = pd.DataFrame(rundb_data, columns=['runnumber','sum_events'])
    df = pd.merge(pivot_df, df2, on='runnumber', how='outer')
    df = df.rename(columns={'sum_events': 'rundb'})

    has_dst_triggered_event = 'dst_triggered_event' in df.columns
    has_dst_calo = 'dst_calo' in df.columns
    has_dst_calofitting = 'dst_calofitting' in df.columns
    
    if has_dst_triggered_event:
        fdf = df[(df['rundb'] > 5) & (df['dst_triggered_event'].isna()) & (df['rundb'].notna())]
        filtered_df = df[(df['rundb'] > 10000) & (df['dst_triggered_event'].notna()) & (df['rundb'].notna())]
    else:
        fdf = df[(df['rundb'] > 5) & (df['rundb'].notna())]
        filtered_df = df[(df['rundb'] > 10000) & (df['rundb'].notna())]
    allrundf = df[(df['rundb'] > 10000) & (df['rundb'].notna())]
    NumNotProduced = len(fdf)
    EventsNotProducted = "{:.3e}".format(fdf['rundb'].sum())
    print()
    print(f"Number of calo physics runs in RunDB not passed to production: {NumNotProduced}")
    print(EventsNotProducted,"events not passed to production")
    print()

    if has_dst_triggered_event:
        print("Fraction of dst_triggered_event/rundb events: {0:.3f}".format(filtered_df['dst_triggered_event'].sum()/filtered_df['rundb'].sum()))
        print("Fraction of dst_triggered_event/rundb events including not produced runs: {0:.3f}".format(allrundf['dst_triggered_event'].sum()/allrundf['rundb'].sum()))
        if has_dst_calofitting:
            print("Fraction of dst_calo_fitting/dst_triggered_event events: {0:.3f}".format(filtered_df['dst_calofitting'].sum()/filtered_df['dst_triggered_event'].sum()))
        if has_dst_calo:
            print("Fraction of dst_calo/rundb events: {0:.3f}".format(filtered_df['dst_calo'].sum()/filtered_df['rundb'].sum()))
            print("Fraction of dst_calo/dst_triggered_event events: {0:.3f}".format(filtered_df['dst_calo'].sum()/filtered_df['dst_triggered_event'].sum()))
    column_sums = filtered_df[['rundb'] + [col for col in ['dst_triggered_event', 'dst_calofitting', 'dst_calo'] if col in df.columns]].sum()
    allcolumn_sums = allrundf[['rundb'] + [col for col in ['dst_triggered_event', 'dst_calofitting', 'dst_calo'] if col in df.columns]].sum()
    long_runs = filtered_df[filtered_df['rundb'] > 10000000]   

    # first plot - number of events dropped from rundb event number through production to dst_triggered_event and eventually to dst_calo 
    plt.figure(figsize=(8, 6)) 
    ax = column_sums.plot(kind='bar', color='skyblue')
    for i, value in enumerate(column_sums):
        ax.text(i, value + 0.01 * value, f'{int(value)}', ha='center', va='bottom')
    plt.title(f'{tag} Calorimeter Events for Runs {start_run}-{end_run}')
    plt.ylabel('Events')
    plt.xticks(rotation=0, ha='center')

    # second plot - number of events dropped from rundb event number through production to dst_triggered_event and eventually to dst_calo 
    # including runs that have not started production
    plt.figure(figsize=(8, 6)) 
    ax = allcolumn_sums.plot(kind='bar', color='skyblue')
    for i, value in enumerate(allcolumn_sums):
        ax.text(i, value + 0.01 * value, f'{int(value)}', ha='center', va='bottom')
    plt.title(f'{tag} Calorimeter Events for All Calo Phyiscs Runs {start_run}-{end_run}')
    plt.ylabel('Events')
    plt.xticks(rotation=0, ha='center')

    # third plot - number of events in runs that are not being produced 
    plt.figure(figsize=(10, 6))  # Create a new figure
    plt.hist(fdf['rundb'], bins=30, edgecolor='black')
    plt.title(f'Run DB event number for runs with no production events for {tag} Runs {start_run}-{end_run}')
    plt.xlabel('Event number')
    plt.ylabel('Frequency')
    plt.grid(True)

    # fourth plot - production event number for long runs (tells us where we cap out in the production)
    plt.figure(figsize=(10, 6))
    plt.hist(long_runs['dst_triggered_event'], bins=30, edgecolor='black')
    plt.title(f'Production event number for runs with > 10M events in production tag {tag} Runs {start_run}-{end_run}')
    plt.xlabel('Prod. event number')
    plt.ylabel('Frequency')
    plt.grid(True)
    plt.show()
    
if __name__ == "__main__":
    main()

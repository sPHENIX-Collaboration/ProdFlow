import pytest
import warnings
import statistics

from rucio.client import Client
client = Client()

import re

relaxed_naming = True

pytest.SCOPE            = "group.sphenix"
pytest.EVENTS_container = "RHIC2023-sPHENIX-CALOR-EVENTS"
pytest.CALOR_container  = "RHIC2023-sPHENIX-CALOR"
pytest.EVENTS_dsnames = []
pytest.CALOR_dsnames  = []
pytest.EVENTS_files   = {}
pytest.CALOR_files    = {}
pytest.EVENTS_sums    = {}
pytest.CALOR_sums     = {}


# beam_emcal_ana381_2023p001-00021739-0090.prdf
pytest.EVENTS_naming  = re.compile("beam_emcal_ana(\d+)_(\w+)-(\d+)-(\d+).prdf")
# DST_CALOR_ana381_TESTp001v3_00021626-0000.root
if relaxed_naming:
    pytest.CALOR_naming   = re.compile("DST_CALOR_ana(\d+)_(\w+)[_-](\d+)-(\d+).root", re.IGNORECASE)
else: 
    pytest.CALOR_naming   = re.compile("DST_CALOR_ana(\d+)_(\w+)-(\d+)-(\d+).root" )   

def test_events_100_the_event_collection_should_be_filled():
    for run in client.list_content( pytest.SCOPE, pytest.EVENTS_container ):
        pytest.EVENTS_dsnames.append(run['name'])
    assert len(pytest.EVENTS_dsnames) > 0, "There are no runs in the %s collection"%pytest.EVENTS_container

def test_events_101_every_run_should_have_file_replicas():
    for dsname in pytest.EVENTS_dsnames:
        pytest.EVENTS_files[dsname] = []
        count=0
        files = client.list_files( pytest.SCOPE, dsname )
        for f in files:
            count=count+1
            pytest.EVENTS_files[dsname].append(f)            
        assert(count>0), "%s is an empty run"

def test_events_102_the_name_of_each_file_must_conform_to_the_naming_convention():
    regex=pytest.EVENTS_naming
    for dsname in pytest.EVENTS_dsnames:
        files = pytest.EVENTS_files[dsname]
        for f in files:
            name=f['name']
            match=regex.match(name)
            assert(match), "%s/%s failed to match the naming convention"%(dsname,name)
            f['match']     = match
            f['match.ana'] = match.group(1)
            f['match.dbt'] = match.group(2)
            f['match.run'] = int( match.group(3) )
            f['match.seq'] = int( match.group(4) )

def test_events_103_the_lowest_sequence_number_is_zero():
    good=True
    for dsname in pytest.EVENTS_dsnames:
        files = pytest.EVENTS_files[dsname]
        seqs=[]
        for f in files:
            seqs.append( f['match.seq'] )
        if min(seqs)>0:
            warnings.warn("%s is missing sequence 0."%dsname)
            good=False

    assert(good), "There were missing output files"

            
def test_events_104_the_highest_sequence_equals_nfiles_minus_one():
    good=True
    for dsname in pytest.EVENTS_dsnames:
        files = pytest.EVENTS_files[dsname]
        seqs=[]
        count=-1
        for f in files:
            seqs.append( f['match.seq'] )
            count+=1
        if max(seqs)!=count:
            warnings.warn("%s has missing output files"%dsname)
            good=False

    assert( good ), "There were missing output files"
    
        
        

#__________________________________________________________________________________________________
def test_calor_200_the_calor_collection_should_be_filled():
    for run in client.list_content( pytest.SCOPE, pytest.CALOR_container ):
        pytest.CALOR_dsnames.append(run['name'])
    assert len(pytest.CALOR_dsnames) > 0, "There are no runs in the %s collection"%pytest.CALOR_container


def test_calor_201_every_run_should_have_file_replicas():
    for dsname in pytest.CALOR_dsnames:
        pytest.CALOR_files[dsname] = []
        count=0
        files = client.list_files( pytest.SCOPE, dsname )
        for f in files:
            count=count+1
            pytest.CALOR_files[dsname].append(f)            
        assert(count>0), "%s is an empty run"


def test_events_202_the_name_of_each_file_must_conform_to_the_naming_convention():
    regex=pytest.CALOR_naming
    for dsname in pytest.CALOR_dsnames:
        files = pytest.CALOR_files[dsname]
        for f in files:
            name=f['name']
            match=regex.match(name)
            assert(match), "%s/%s failed to match the naming convention"%(dsname,name)
            f['match']=match
            f['match.ana']=match.group(1)
            f['match.dbt']=match.group(2)
            f['match.run']=match.group(3)
            f['match.seq']=match.group(4)


def test_calor_203_the_lowest_sequence_number_is_zero():
    good=True
    for dsname in pytest.CALOR_dsnames:
        files = pytest.CALOR_files[dsname]
        seqs=[]
        for f in files:
            seqs.append( f['match.seq'] )
        if min(seqs)>0:
            warnings.warn("%s is missing sequence 0."%dsname)
            good=False

    assert(good), "There were missing output files"

            
def test_calor_204_the_highest_sequence_equals_nfiles_minus_one():
    good=True
    for dsname in pytest.CALOR_dsnames:
        files = pytest.CALOR_files[dsname]
        seqs=[]
        count=-1
        for f in files:
            seqs.append( f['match.seq'] )
            count+=1
        if max(seqs)!=count:
            warnings.warn("%s has missing output files"%dsname)
            good=False

    assert( good ), "There were missing output files"            

#__________________________________________________________________________________________________
def test_joint_300_the_event_and_calor_collections_should_have_the_same_number_of_runs():
    assert( len(pytest.EVENTS_dsnames)==len(pytest.CALOR_dsnames) )


        



#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Aug 20 14:19:54 2021

@author: gregstacey
"""

import os
import pandas as pd
import numpy as np
import sys
from itertools import chain
from rdkit import Chem
from tqdm import tqdm

if os.path.isdir("~/git/bespoke-deepgen"):
    git_dir = os.path.expanduser("~/git/bespoke-deepgen")
elif os.path.isdir("/Users/gregstacey/Academics/Foster/Metabolomics/bespoke-deepgen"):
    git_dir = os.path.expanduser("~/Academics/Foster/Metabolomics/bespoke-deepgen")
elif os.path.isdir("/scratch/st-ljfoster-1/staceyri/bespoke-deepgen"):
    git_dir = os.path.expanduser("/scratch/st-ljfoster-1/staceyri/bespoke-deepgen")
python_dir = git_dir + "/python"
os.chdir(python_dir)
sys.path.append(python_dir)

# import functions
from functions import clean_mols, remove_salts_solvents, read_smiles, \
    NeutraliseCharges
# import Vocabulary
from datasets import Vocabulary


# read full hmdb
data = pd.read_csv('../data/hmdb/20200730_hmdb_classifications-canonical.csv.gz')


# write smiles files
# full
data.to_csv("../data/hmdb/hmdb.smi", index = False)

# kingdoms
unq = data["kingdom"].dropna().unique()
for ii in range(0, len(unq)):
    ss = ''.join(e for e in unq[ii] if e.isalnum())
    fn = "../data/hmdb/kingdom/" + unq[ii] + '.smi'
    data[data["kingdom"]==unq[ii]].to_csv(fn, index = False)
    
# superklass
unq = data["superklass"].dropna().unique()
for ii in range(0, len(unq)):
    ss = ''.join(e for e in unq[ii] if e.isalnum())
    fn = "../data/hmdb/superklass/" + ss + '.smi'
    data[data["superklass"]==unq[ii]].to_csv(fn, index = False)
    
# klass
unq = data["klass"].dropna().unique()
for ii in range(0, len(unq)):
    ss = ''.join(e for e in unq[ii] if e.isalnum())
    fn = "../data/hmdb/klass/" + ss + '.smi'
    data[data["klass"]==unq[ii]].to_csv(fn, index = False)
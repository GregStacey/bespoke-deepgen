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
data = data.dropna(subset = ["canonical_smiles"]) # remove NA


# write smiles files

# full
sm = pd.DataFrame({'canonical_smiles': data["canonical_smiles"].unique()})
sm.to_csv("../data/hmdb/hmdb.smi", index = False, columns = ["canonical_smiles"], header = False)

# kingdoms
unq = data["kingdom"].dropna().unique()
if not os.path.isdir("../data/hmdb/kingdom/"):
    os.makedirs("../data/hmdb/kingdom/")
for ii in range(0, len(unq)):
    ss = ''.join(e for e in unq[ii] if e.isalnum())
    fn = "../data/hmdb/kingdom/" + ss + '.smi'
    sm = data[data["kingdom"]==unq[ii]]
    sm = pd.DataFrame({'canonical_smiles': sm["canonical_smiles"].unique()})
    sm.to_csv(fn, index = False, columns = ["canonical_smiles"], header = False)
    
# superklass
unq = data["superklass"].dropna().unique()
if not os.path.isdir("../data/hmdb/superklass/"):
    os.makedirs("../data/hmdb/superklass/")
for ii in range(0, len(unq)):
    ss = ''.join(e for e in unq[ii] if e.isalnum())
    fn = "../data/hmdb/superklass/" + ss + '.smi'
    sm = data[data["superklass"]==unq[ii]]
    sm = pd.DataFrame({'canonical_smiles': sm["canonical_smiles"].unique()})
    sm.to_csv(fn, index = False, columns = ["canonical_smiles"], header = False)
    
# klass
unq = data["klass"].dropna().unique()
if not os.path.isdir("../data/hmdb/klass/"):
    os.makedirs("../data/hmdb/klass/")
for ii in range(0, len(unq)):
    ss = ''.join(e for e in unq[ii] if e.isalnum())
    fn = "../data/hmdb/klass/" + ss + '.smi'
    sm = data[data["klass"]==unq[ii]]
    sm = pd.DataFrame({'canonical_smiles': sm["canonical_smiles"].unique()})
    sm.to_csv(fn, index = False, columns = ["canonical_smiles"], header = False)
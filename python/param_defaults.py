#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Sep 23 12:23:27 2021

@author: gregstacey
"""


class Object(object):
    pass

## train_model.py

args = Object()
# input file
args.original_file = "/scratch/st-ljfoster-1/staceyri/bespoke-deepgen/data/hmdb/superklass/Benzenoids_clean.smi"
args.sampled_files = "/scratch/st-ljfoster-1/staceyri/bespoke-deepgen/experiments/01_kategory/Benzenoids/sample-1-SMILES.smi"
args.selfies = False
# output files
args.output_dir = "/scratch/st-ljfoster-1/staceyri/bespoke-deepgen/experiments/01_kategory/Benzenoids/"
# RNN parameters
args.rnn_type = "GRU"
args.embedding_size = 128
args.hidden_size = 512
args.n_layers = 3
args.dropout = 0
args.bidirectional = False
args.nonlinearity = "tanh"
args.tie_weights = False
# optimization parameters
args.learning_rate = 0.001
args.learning_rate_decay = None
args.learning_rate_decay_steps = 10000
args.gradient_clip = None
# training schedule
args.seed = 0
args.batch_size = 128
args.max_epochs = 1000
args.patience = 100
# sampling from trained models
args.sample_idx = 0
args.sample_every_steps = None  # ??
args.log_every_steps = None  # ??
args.sample_every_epochs = None  # ??
args.log_every_epochs = None  # ??
args.sample_size = 100000
# start with pretrained model
args.pretrain_model = None
# enforce a larger vocabulary
args.vocab_file = None
# for use in grid
args.stop_if_exists = False



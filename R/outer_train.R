options(stringsAsFactors = FALSE)
source("R/functions.R")
select = dplyr::select


# detect system
if (dir.exists("/scratch/st-ljfoster-1/logs/")) {
  this.system = "sockeye"
  project_dir = "/scratch/st-ljfoster-1/staceyri/bespoke-deepgen/"
} else if (dir.exists("/home/centos/")) {
  this.system = "ronin"
} else if (dir.exists('/Users/gregstacey/')) {
  this.system = "macbook"
}


job_name = 'train'

# find all cleaned, non-enumerated .smi files
fns = dir("data/hmdb/", pattern = "_clean.smi", full.names = T, recursive = T) %>%
  # filter out enumerated files
  .[!grepl("enum", .)] %>%
  normalizePath()

# just superklasses + kingdoms for now
fns = fns[grepl("superklass", fns) | grepl("kingdom", fns)]

# only .smi files with >100 samples
nsample = sapply(fns, function(x) read_csv(x) %>% nrow())
fns = fns[nsample>135]

# set up grid
jobs = tidyr::crossing(enum = 0,
                       n_layers = 3,
                       emb_size = 128,
                       hidden_size = 512,
                       rnn_type = "GRU",
                       dropout = 0,
                       batch_size = 128,
                       learning_rate = 10000,
                       sample_idx = 0:2,
                       smiles_file = fns) %>%
  mutate(output_dir = paste0(project_dir, "experiments/01_kategory/",
                             basename(smiles_file) %>% gsub("_clean.smi", "", .), "/")) %>%
  mutate(generated_samples = paste0(output_dir, "sample-", sample_idx+1,"-SMILES.smi")) %>%
  mutate(model_file = paste0(output_dir, "model-", sample_idx+1,".pt")) %>%
  # # vocab file
  # mutate(fn_vocab = paste0("experiments/01_kategory/",
  #                          file_path_sans_ext(basename(smiles_file)))) %>%
  # filter out jobs that exist
  filter(!file.exists(model_file)) %>%
  as.data.frame()

# reduce to <=50 jobs on sockeye
if (this.system=="sockeye") {
  jobs = jobs[sample(nrow(jobs), 49),]
}

# make output dirs if needed
for (ii in 1:length(unique(jobs$output_dir))) {
  if (!dir.exists(unique(jobs$output_dir)[ii])) dir.create(unique(jobs$output_dir)[ii])
}

# write the grid that still needs to be run
grid_file = paste0(getwd(), "/sh/grids/", job_name, ".txt")
grid_dir = dirname(grid_file)
if (!dir.exists(grid_dir))
  dir.create(grid_dir, recursive = TRUE)
write.table(jobs, grid_file, quote = FALSE, row.names = FALSE, sep = "\t")

# make log folder if needed
log.dir = switch(this.system,
                 sockeye = paste0("/scratch/st-ljfoster-1/logs/bespoke-deepgen/", job_name, "/"),
                 ronin = paste0("/home/centos/projects/bespoke-deepgen/logs/", job_name, "/"),
                 macbook = paste0("/Users/gregstacey/Academics/Foster/Metabolomics/bespoke-deepgen/logs/", job_name, "/"))
if (!dir.exists(log.dir)) dir.create(log.dir, recursive = T)

# write the sh file dynamically
sh_file = paste0('sh/', job_name, ".sh")
write_sh(job_name = job_name,
         sh_file = sh_file,
         grid_file = grid_file,
         log.dir = log.dir,
         inner_file = 'python/train_model.py',
         system = this.system,
         time = 23,
         mem = 12, gpu = T)


# finally, run the job on whatever system we're on
args = data.frame(allocation = "st-ljfoster-1-gpu")
submit_job(nrow(jobs), sh_file, args$allocation, this.system)



module load Software_Collection/2021
module load gcc/9.4.0 openmpi python singularity

LINE_IDX=$((PBS_ARRAY_INDEX + 1))
LINE=`sed "${LINE_IDX}q;d" /scratch/st-ljfoster-1/staceyri/bespoke-deepgen/sh/grids/train.txt`
IFS=$'\t' PARAMS=($LINE)
AUGMENTATION=${PARAMS[0]}
N_LAYERS=${PARAMS[1]}
EMB_SIZE=${PARAMS[2]}
HIDDEN_SIZE=${PARAMS[3]}
RNN_TYPE=${PARAMS[4]}
DROPOUT=${PARAMS[5]}
BATCH_SIZE=${PARAMS[6]}
LEARNING_RATE=${PARAMS[7]}
SAMPLE_IDX=${PARAMS[8]}
SMILES_FILE=${PARAMS[9]}
OUTPUT_DIR=${PARAMS[10]}

cd /scratch/st-ljfoster-1/staceyri/bespoke-deepgen/python

singularity exec --nv /arc/project/st-ljfoster-1/Conda_Container.sif python3 train_model.py --smiles_file $SMILES_FILE --output_dir $OUTPUT_DIR --rnn_type $RNN_TYPE --hidden_size $HIDDEN_SIZE --embedding_size $EMB_SIZE --n_layers $N_LAYERS --dropout $DROPOUT --learning_rate $LEARNING_RATE --batch_size $BATCH_SIZE --sample_size 500000 --log_every_steps 100 --max_epochs 999999 --patience 50000 --stop_if_exists
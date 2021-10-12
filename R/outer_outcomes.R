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

# find sample-x-SMILES.smi files
fns = dir("experiments/01_kategory/", pattern = "sample-", full.names = T, recursive = T) %>%
  # ensure sample-x-SMILES.smi files
  .[grepl("-SMILES.smi", .)] %>%
  # filter out enumerated files %>%
  .[!grepl("enum", .)] %>%
  normalizePath()

# parser = argparse.ArgumentParser(
#   description='Calculate a series of properties for a set of SMILES')
# parser.add_argument('--smiles_file', type=str,
#                     help='file containing SMILES')
# parser.add_argument('--reference_file', type=str,
#                     help='file containing a reference set of SMILES')
# parser.add_argument('--output_dir', type=str,
#                     help='directory to save output to')
# parser.add_argument('--selfies', dest='selfies',
#                     help='calculate outcomes for molecules in SELFIES format',
#                     action='store_true')
# parser.add_argument('--deepsmiles', dest='deepsmiles',
#                     help='calculate outcomes for molecules in DeepSMILES format',
#                     action='store_true')
# parser.add_argument('--stop_if_exists', dest='stop_if_exists',
#                     action='store_true')


# set up grid
jobs = tidyr::crossing(smiles_file = fns,
                       reference_file = "data/hmdb/20200730_hmdb_classifications-canonical.csv.gz") %>%
  mutate(output_dir = paste0(project_dir, "experiments/01_kategory/",
                             basename(smiles_file) %>% gsub("_clean.smi", "", .), "/"),
         sample_IDX = basename(fns) %>% gsub('\\D+','', .) %>% as.numeric()) %>%
  mutate(model_file = paste0(output_dir, "model-", sample_IDX,".pt"),
         outcomes_file = paste0(output_dir, "outcomes-", sample_IDX), 
         selfies = FALSE,
         deepsmiles = FALSE,
         stop_if_exists = TRUE) %>%
  # # vocab file
  # mutate(fn_vocab = paste0("experiments/01_kategory/",
  #                          file_path_sans_ext(basename(smiles_file)))) %>%
  # filter out jobs that exist
  filter(!file.exists(outcomes_file)) %>%
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


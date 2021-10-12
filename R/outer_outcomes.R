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

job_name = 'calculate_outcomes'

# find sample-x-SMILES.smi files
fns = dir("experiments/01_kategory/", pattern = "sample-", full.names = T, recursive = T) %>%
  # ensure sample-x-SMILES.smi files
  .[grepl("-SMILES.smi", .)] %>%
  # filter out enumerated files %>%
  .[!grepl("enum", .)] %>%
  normalizePath()

# find original files for samples
types = sapply(fns, function(x) basename(dirname(x))) %>% unlist() %>% unname()
all_original_files = dir("data/hmdb/", pattern = "clean.smi", full.names = T, recursive = T)
original_files = all_original_files[sapply(types, function(x) grep(x, all_original_files))]

# set up grid
jobs = data.frame(smiles_file = fns,
                  original_files = original_files,
                  reference_file = "data/hmdb/20200730_hmdb_classifications-canonical.csv.gz") %>%
  mutate(output_dir = paste0(project_dir, "experiments/01_kategory/",
                             basename(smiles_file) %>% gsub("_clean.smi", "", .), "/"),
         sample_IDX = basename(fns) %>% gsub('\\D+','', .) %>% as.numeric(),
         model_file = paste0(output_dir, "model-", sample_IDX,".pt"),
         outcomes_file = paste0(output_dir, "outcomes-", sample_IDX), 
         selfies = FALSE,
         deepsmiles = FALSE,
         stop_if_exists = TRUE,
         minimal = FALSE) %>%
  # filter out jobs that exist
  filter(!file.exists(outcomes_file)) %>%
  as.data.frame()

# reduce to <=50 jobs on sockeye
if (this.system=="sockeye" & nrow(jobs)>=50) {
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
         inner_file = 'python/calculate_outcomes.py',
         system = this.system,
         time = 23,
         mem = 12, gpu = T)


# finally, run the job on whatever system we're on
args = data.frame(allocation = "st-ljfoster-1-gpu")
submit_job(nrow(jobs), sh_file, args$allocation, this.system)


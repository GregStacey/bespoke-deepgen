options(stringsAsFactors = FALSE)
source("R/functions.R")
select = dplyr::select


# detect system
if (dir.exists("/scratch/st-ljfoster-1/logs/")) {
  this.system = "sockeye"
} else if (dir.exists("/home/centos/projects/")) {
  this.system = "ronin"
} else if (dir.exists('/Users/gregstacey/')) {
  this.system = "macbook"
}


job_name = 'enumerate'

# find all non-enumerated .smi files
fns = dir("data/hmdb/", pattern = ".smi", full.names = T, recursive = T) %>%
  # filter out enumerated files
  .[!grepl("enum", .)]

# set up grid
jobs = tidyr::crossing(fns,
                       enum = c(5, 30)) %>%
  # include output files in grid
  #mutate(tmp = ) %>%
  mutate(sf = str_replace(fns, ".smi", paste0("_enum", enum, ".smi"))) %>%
  as.data.frame()


# write the grid that still needs to be run
grid_file = paste0("sh/grids/", job_name, ".txt")
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
         inner_file = 'python/augment-SMILES.py',
         system = this.system,
         time = 23,
         mem = 2)



# finally, run the job on whatever system we're on
args = data.frame(allocation = "st-ljfoster-1")
submit_job(nrow(jobs), sh_file, args$allocation, this.system)

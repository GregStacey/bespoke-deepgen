
require(readr)
require(dplyr)
require(tidyr)
require(stringr)
require(magrittr)


# submit a job to the appropriate cluster
submit_job = function(jobs0, script, allocation,
                      system = c('cedar', 'sockeye', 'ronin'),
                      jobs_per_array = 100) {
  system = match.arg(system)
  
  if (is.character(jobs0)){
    jobs = as.data.frame(read_csv(jobs0))
    Njobs = nrow(jobs)+1
  } else if(is.numeric(jobs0)) {
    Njobs = jobs0+1
  }
  
  
  if (system == 'ronin') {
    system(paste0("sbatch --array=1-", Njobs, 
                  " ", script))
  } else if (system == 'sockeye') {
    n_jobs = Njobs
    ## Sockeye only lets you run 1,000 jobs at a time
    n_submissions = ifelse(n_jobs > jobs_per_array,
                           ceiling(n_jobs / jobs_per_array), 1)
    for (submission_idx in seq_len(n_submissions)) {
      job_start = (submission_idx - 1) * jobs_per_array + 1
      job_end = ifelse(submission_idx == n_submissions,
                       ifelse(n_jobs %% jobs_per_array == 0,
                              submission_idx * jobs_per_array,
                              job_start - 1 + n_jobs %% jobs_per_array),
                       submission_idx * jobs_per_array)
      system(paste0("qsub -A ", allocation, " -J ", job_start, "-", job_end,
                    " ", script))
    }
  }
}


write_sh = function(job_name,
                    sh_file,
                    grid_file,
                    inner_file,
                    system = c('sockeye', 'ronin', 'macbook'),
                    time = 24, ## in hours
                    mem = 4, ## in GB
                    cpus = 1,
                    cpu_arch = NULL,
                    log.dir = NULL,
                    other_args = NULL
) {
  system = match.arg(system)
  
  # read the grid
  grid = read.delim(grid_file)
  
  # set up the script
  if (system == 'sockeye') {
    
    if (!is.null(cpu_arch)) cpu_arch = paste0(":cpu_arch=", cpu_arch)
    header_lines = c(
      '#!/bin/bash',
      paste0('#PBS -l walltime=', time, ':00:00,select=1:ncpus=', cpus,
             ':mem=', mem, 'gb', cpu_arch),
      paste0('#PBS -N ', job_name),
      paste0('#PBS -o ', log.dir, '/', job_name, '-^array_index^.out'),
      paste0('#PBS -e ', log.dir, '/', job_name, '-^array_index^.err'),
      ''
    )
    
    env_lines = c(
      'conda activate chemenv',
      'module load gcc/9.1.0',
      'module load openmpi/3.1.5',
      'module load netcdf/4.7.3',
      'module load r/3.6.2-py3.7.3',
      'cd /scratch/st-ljfoster-1/staceyri/bespoke-deepgen/',
      ''
    )
  } else if (system == 'ronin' | system=='macbook') {
  } else {
    stop('not sure how to write a sh file for: ', system)
  }
  
  # set up the final part of the script, which is platform-agnostic
  idx_var = switch(system,
                   'ronin' = '$SLURM_ARRAY_TASK_ID',
                   'sockeye' = '$PBS_ARRAY_INDEX')
  run_lines = c(
    paste0('LINE=`cat ',grid_file,' | head -', idx_var, ' | tail -1`'),
    paste0("INPUTFILE=`echo $LINE | awk '{print $1}'`"),
    paste0("ENUM=`echo $LINE | awk '{print $2}'`"),
    paste0("OUTPUTFILE=`echo $LINE | awk '{print $3}'`"),
    '',
    'python python/augment-SMILES.py --input_file $INPUTFILE --output_file $OUTPUTFILE --enum_factor $ENUM '
  )
  
  # write to file
  lines = c(header_lines,
            env_lines,
            run_lines)
  sh_dir = dirname(sh_file)
  if (!dir.exists(sh_dir)) 
    dir.create(sh_dir, recursive = TRUE)
  writeLines(lines, sh_file)
}
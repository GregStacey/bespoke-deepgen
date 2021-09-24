
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


write_sh = function(job_name = c("clean", "enumerate", "train"),
                    sh_file,
                    grid_file,
                    inner_file,
                    system = c('sockeye', 'ronin', 'macbook'),
                    time = 24, ## in hours
                    mem = 4, ## in GB
                    cpus = 1,
                    cpu_arch = NULL,
                    gpu = F,
                    log.dir = NULL,
                    other_args = NULL
) {
  system = match.arg(system)
  job_name = match.arg(job_name)
  
  # read the grid
  grid = read.delim(grid_file)
  
  # set up the script
  if (system == 'sockeye') {
    
    if (!is.null(cpu_arch)) cpu_arch = paste0(":cpu_arch=", cpu_arch)
    header_lines = c(
      '#!/bin/bash',
      paste0('#PBS -l walltime=', time, ':00:00,select=1:n', 
             ifelse(gpu, 'gpus=', 'cpus='), cpus,
             ':mem=', mem, 'gb'),
      paste0('#PBS -N ', job_name),
      paste0('#PBS -o ', log.dir, '/', job_name, '-^array_index^.out'),
      paste0('#PBS -e ', log.dir, '/', job_name, '-^array_index^.err'),
      ''
    )
    
    env_lines = c(
      'module load Software_Collection/2021',
      'module load gcc/9.4.0 openmpi python singularity',
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
  if (job_name=="enumerate"){
    run_lines = c(
      paste0('LINE=`cat ',grid_file,' | head -', idx_var, ' | tail -1`'),
      paste0("INPUTFILE=`echo $LINE | awk '{print $1}'`"),
      paste0("ENUM=`echo $LINE | awk '{print $2}'`"),
      paste0("OUTPUTFILE=`echo $LINE | awk '{print $3}'`"),
      'python augment-SMILES.py --input_file $INPUTFILE --output_file $OUTPUTFILE --enum_factor $ENUM '
    )
  } else if (job_name=="clean") {
    run_lines = c(
      paste0('LINE=`cat ',grid_file,' | head -', idx_var, ' | tail -1`'),
      paste0("INPUTFILE=`echo $LINE | awk '{print $1}'`"),
      paste0("OUTPUTFILE=`echo $LINE | awk '{print $2}'`"),
      'python clean-SMILES.py $INPUTFILE'
    )
  } else if (job_name=="train") {
    run_lines = c(
      'LINE_IDX=$((PBS_ARRAY_INDEX + 1))',
      paste0('LINE=`sed "${LINE_IDX}q;d" ', grid_file, '`'),
      "IFS=$'\\t' PARAMS=($LINE)",
      'AUGMENTATION=${PARAMS[0]}',
      'N_LAYERS=${PARAMS[1]}',
      'EMB_SIZE=${PARAMS[2]}',
      'HIDDEN_SIZE=${PARAMS[3]}',
      'RNN_TYPE=${PARAMS[4]}',
      'DROPOUT=${PARAMS[5]}',
      'BATCH_SIZE=${PARAMS[6]}',
      'LEARNING_RATE=${PARAMS[7]}',
      'SAMPLE_IDX=${PARAMS[8]}',
      'SMILES_FILE=${PARAMS[9]}',
      'OUTPUT_DIR=${PARAMS[10]}',
      '',
      'singularity exec --nv /arc/project/st-ljfoster-1/staceyri_R_Container.sif python3 train_model.py \\ ',
      '    --smiles_file $SMILES_FILE \\ ',
      '    --output_dir $OUTPUT_DIR \\ ',
      '    --rnn_type $RNN_TYPE \\ ',
      '    --hidden_size $HIDDEN_SIZE \\ ',
      '    --embedding_size $EMB_SIZE \\ ',
      '    --n_layers $N_LAYERS \\ ',
      '    --dropout $DROPOUT \\ ',
      '    --learning_rate $LEARNING_RATE \\ ',
      '    --batch_size $BATCH_SIZE \\ ',
      '    --sample_size 500000 \\ ',
      '    --log_every_steps 100 \\ ',
      '    --max_epochs 999999 \\ ',
      '    --patience 50000 \\ ',
      '    --stop_if_exists'
    )
  }
  
  # write to file
  lines = c(header_lines,
            env_lines,
            run_lines)
  sh_dir = dirname(sh_file)
  if (!dir.exists(sh_dir)) 
    dir.create(sh_dir, recursive = TRUE)
  writeLines(lines, sh_file)
}
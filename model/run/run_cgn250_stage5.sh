#!/bin/bash

# arguments
org_lang=$1
tar_lang=$2
org_task=$3
tar_task=$4

dec_tag=${dec_tag:-""}
dir_tag=${dir_tag:-""}
transfer=${transfer:-0}
n_jobs=${n_jobs:-32}
n_average=${n_average:-10}

while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi

  shift
done


echo "<org_lang> = ${org_lang}"
echo "<tar_lang> = ${tar_lang}"
echo "<org_task> = ${org_task}"
echo "<tar_task> = ${tar_task}"
echo "<dec_tag> = ${dec_tag}"
echo "<dir_tag> = ${dir_tag}"
echo "<transfer> = ${transfer}"
echo "<n_jobs> = ${n_jobs}"
echo "<n_average> = ${n_average}"

transfer_learning=${transfer}


# Just run them, don't think about it! 
. ./path.sh || exit 1;
. ./cmd.sh || exit 1;
#export PATH=.:/esat/spchtemp/spchdisk_orig/svandere/espnet/espnet:/users/spraak/spch/prog/spch/ESPnet/kaldi/egs/wsj/s5/utils/parallel:/users/spraak/spch/prog/spch/ESPnet/kaldi/src/featbin:$PATH
export PATH=.:/esat/spchtemp/spchdisk_orig/svandere/espnet/espnet:$PATH

# general configuration - important for the next steps
backend=pytorch
stage=5        # start from 0 if you need to start from data preparation
stop_stage=5   # determine when to stop
ngpu=0         # number of gpus ("0" uses cpu, otherwise use gpu)
debugmode=1
dumpdir=dump   # directory to dump full features
exp=exp/cl
N=0            # number of minibatches to be used (mainly for debugging). "0" uses all minibatches.
verbose=0      # verbose option
seed=1

len_dec_tag=${#dec_tag}
len_dir_tag=${#dir_tag}

if [ ${len_dec_tag} -gt 0 ]; then
       dec_tag="_${dec_tag}"
fi
if [ ${len_dir_tag} -gt 0 ]; then
       dir_tag="_${dir_tag}"
fi 


# exp tag - related to vocabulary
nbpe=250     # how many subwords?
bpemode=unigram   # unigram or bpe?
tag=uni${nbpe} # tag for managing experiments.

# feature configuration
do_delta=false

# sample filtering
min_io_delta=4  # samples with `len(input) - len(output) * min_io_ratio < min_io_delta` will be removed.

# config files - files for preprocessing, training and decoding
preprocess_config=specaug.yaml  # use conf/specaug.yaml for data augmentation
train_config=train_cgn250.yaml
#lm_config=conf/lm.yaml
decode_config=decode_cgn250.yaml

# decoding parameter
#n_average=${n_average} # use 1 for RNN models
recog_model=model.acc.best # set a model to be used for decoding: 'model.acc.best' or 'model.loss.best'

# data - information related to the data
cgn_path=/users/spraak/spchdata/cgn
lang=${tar_lang}   # choose which languages to use
comp="b;f;g;h;i;j;k;l;m;n;o"  # choose which components to use
compname="${comp//;}"
task=${tar_task} # task to evaluate

# as we are decoding, it is also important which language and components we used for training
source_lang=${org_lang}
source_comp="b;f;g;h;i;j;k;l;m;n;o"
source_langname=${source_lang//;}
source_compname=${source_comp//;}
source_task=${org_task}

# Run the following file, don't think about it!
. utils/parse_options.sh || exit 1;

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail
unset PYTHONPATH

# Setting some names
train_set=train_${lang}_${compname}_${task}
train_dev=dev_${lang}_${compname}_${task}
recog_set=${train_dev}
train_test=test_${lang}_${compname}_${task}
train_mem=mem_${lang}_${compname}_${task}${mem_tag}

# Create two dirs, to dump the train and dev features respectively
feat_ts_dir=${dumpdir}/${train_test}/delta${do_delta}; mkdir -p ${feat_ts_dir}

# the dictionary is always that from NL-main
dict=data/lang_char/train_nl_bfghijklmno_nl_main_unigram250_units.txt
bpemodel=data/lang_char/train_nl_bfghijklmno_nl_main_unigram250

echo "dictionary: ${dict}"



if [ ${transfer_learning} -eq 1 ]; then
	expdir=${exp}/train_${source_langname}_${source_compname}_${source_task}_transfer_${backend}_uni${nbpe}${dir_tag}
else
        expdir=${exp}/train_${source_langname}_${source_compname}_${source_task}_${backend}_uni${nbpe}${dir_tag}
fi

if [ ${stage} -le 5 ] && [ ${stop_stage} -ge 5 ]; then
    echo "stage 5: Decoding"
    echo "Preparing..."
    nj=${n_jobs}
    # If the model was a transformer, we take the average over the last n_average models
    if [[ $(get_yaml.py ${train_config} model-module) = *transformer* ]]; then
       recog_model=model.last${n_average}.avg.best
       average_checkpoints.py --backend ${backend} \
                              --snapshots ${expdir}/results/snapshot.ep.* \
                              --out ${expdir}/results/${recog_model} \
                              --num ${n_average}
    fi

    echo "Using recog_model = ${recog_model}"  
   
    decode_dir=decode_${lang}_${compname}_${task}${dec_tag}
    splitjson.py --parts ${nj} ${feat_ts_dir}/data_${bpemode}${nbpe}.json
    
    echo "Ready to start decoding!"

    OMP_NUM_THREADS=1 ${decode_cmd} --num_threads 1 --max-jobs-run 1 JOB=1:${nj} ${expdir}/${decode_dir}/log/decode.JOB.log \
	asr_recog.py \
          --config ${decode_config} \
          --ngpu ${ngpu} \
          --backend ${backend} \
          --recog-json ${feat_ts_dir}/split${nj}utt/data_${bpemode}${nbpe}.JOB.json \
          --result-label ${expdir}/${decode_dir}/data.JOB.json \
          --model ${expdir}/results/${recog_model} &
    wait

    espnet_utils/score_sclite.sh --wer true --bpe ${nbpe} --bpemodel ${bpemodel}.model \ 
	${expdir}/${decode_dir} ${dict}
    echo "Succesfully finished DECODING"
fi

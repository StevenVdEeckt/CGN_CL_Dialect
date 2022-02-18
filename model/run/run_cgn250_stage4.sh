#!/bin/bash


# Just run them, don't think about it! 
. ./path.sh || exit 1;
. ./cmd.sh || exit 1;
export PATH=.:/users/spraak/spch/prog/spch/ESPnet/kaldi/egs/wsj/s5/utils/parallel:/users/spraak/spch/prog/spch/ESPnet/kaldi/src/featbin:$PATH


# arguments
lang=$1
task=$2
exp_tag=$3


batch_size=${batch_size:-16}
init=${init:-""}
cl_algorithm=${cl_algorithm:-"none"}
resume=${resume:-0}
memory=${memory:-"memory"}
lambda=${lambda:-1}

while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi

  shift
done



length_init=${#init}

echo "<lang> = ${lang}"
echo "<task> = ${task}"
echo "<exp_tag> = ${exp_tag}"
echo "<batch_size> = ${batch_size}"
echo "<init> = ${init}"
echo "<cl_algorithm> = ${cl_algorithm}"
echo "<memory> = ${memory}"
echo "<resume> = ${resume}"
echo "<lambda> = ${lambda}"
echo "CUDA version: $(nvcc --version)"


# general configuration - important for the next steps
backend=pytorch
stage=4        # start from 0 if you need to start from data preparation
stop_stage=4   # determine when to stop
ngpu=1         # number of gpus ("0" uses cpu, otherwise use gpu)
debugmode=1
dumpdir=dump   # directory to dump full features
exp=exp/cl
N=0            # number of minibatches to be used (mainly for debugging). "0" uses all minibatches.
verbose=0      # verbose option
seed=1
res=false
if [ ${resume} -eq 1 ]; then
   res=true
fi

transfer_learning=false
if [ ${length_init} -gt 0 ]; then
   transfer_learning=true
fi


if [ ! -z "${exp_tag}" ]; then
	exp_tag="_${exp_tag}"
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
if [ ${transfer_learning} = true ]; then
   train_config=train_cgn250_ft.yaml
fi

echo "Using train-file= ${train_config}"

#lm_config=conf/lm.yaml
decode_config=decode_cgn250.yaml

# decoding parameter
n_average=10 # use 1 for RNN models
recog_model=model.acc.best # set a model to be used for decoding: 'model.acc.best' or 'model.loss.best'

# data - information related to the data
cgn_path=/users/spraak/spchdata/cgn
#lang='nl'
#task="nl_main"   # choose from  nl_main, nl_rest, vl_main, vl_rest
comp="b;f;g;h;i;j;k;l;m;n;o"  # choose which components to use
compname="${comp//;}"


# the dictionary and optionally a pre-trained model
dict=data/lang_char/train_nl_bfghijklmno_nl_main_unigram250_units.txt
bpemodel=data/lang_char/train_nl_bfghijklmno_nl_main_unigram250

# Run the following file, don't think about it! 
. utils/parse_options.sh || exit 1;

frame_id_to_one_hot="{\"n\": 0, \"v\": 1}"

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail
unset PYTHONPATH

train_set=train_${lang}_${compname}_${task}
train_dev=dev_${lang}_${compname}_${task}
recog_set=${train_dev}

# Create two dirs, to dump the train and dev features respectively
feat_tr_dir=${dumpdir}/${train_set}/delta${do_delta}; mkdir -p ${feat_tr_dir}
feat_dt_dir=${dumpdir}/${train_dev}/delta${do_delta}; mkdir -p ${feat_dt_dir}

if [ ${transfer_learning} = true ]; then
  expname=${train_set}_transfer_${backend}_${tag}
else
  expname=${train_set}_${backend}_${tag}
fi

expdir=$exp/${expname}${exp_tag}
mkdir -p ${expdir}

pre_trained_model=""
pre_trained_outdir=""
if [ ${length_init} -gt 0 ]; then
   pre_trained_model=/esat/spchtemp/spchdisk_orig/svandere/espnet/asr/exp1/exp/cl/${init}/results/model.last10.avg.best
   pre_trained_outdir=/esat/spchtemp/spchdisk_orig/svandere/espnet/asr/exp1/exp/cl/${init}/results
fi 

memory_json=""
length_memory=${#memory}
if [ ${length_memory} -gt 0 ]; then
  memory_json=${dumpdir}/${memory}/delta${do_delta}/data_${bpemode}${nbpe}.json
fi


resume=somefile
if [ ${res} = true ]; then
   for snapshot in ${expdir}/results/snapshot.ep.*; do
         if [ ${snapshot} -nt ${resume} ]; then
               resume=${snapshot}
         fi
   echo "Resuming from.. ${resume}"
   done
fi

if [ ${resume} = "somefile" ]; then
    resume=""
fi

if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
    echo "stage 4: Network Training"

    ${cuda_cmd} --gpu ${ngpu} ${expdir}/train.log \
        CUDA_LAUNCH_BLOCKING=1 asr_train.py \
        --config ${train_config} \
        --preprocess-conf ${preprocess_config} \
        --ngpu ${ngpu} \
        --backend ${backend} \
        --outdir ${expdir}/results \
        --tensorboard-dir tensorboard/${expname}${exp_tag} \
        --debugmode ${debugmode} \
        --dict ${dict} \
        --debugdir ${expdir} \
        --minibatches ${N} \
        --verbose ${verbose} \
        --seed ${seed} \
        --train-json ${feat_tr_dir}/data_${bpemode}${nbpe}.json \
        --valid-json ${feat_dt_dir}/data_${bpemode}${nbpe}.json \
        --memory-json ${memory_json} \
        --reg-importance ${lambda} \
        --batch-count seq \
        --sample_measure ${sample_measure} \
        --freeze_strategy ${freeze_strategy} \
        --batch-size ${batch_size} \
        --dec-init "${pre_trained_model}" \
        --enc-init "${pre_trained_model}" \
        --enc-init-mods encoder. \
        --dec-init-mods decoder. \
        --pre_trained_outdir "${pre_trained_outdir}" \
        --resume ${resume}
     
    
   
fi

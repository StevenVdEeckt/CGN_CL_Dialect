#!/bin/bash


. ./path.sh || exit 1;
. ./cmd.sh || exit 1;
export PATH=.:/users/spraak/spch/prog/spch/ESPnet/kaldi/egs/wsj/s5/utils/parallel:/users/spraak/spch/prog/spch/ESPnet/kaldi/src/featbin:$PATH

# general configuration - important for the next steps
backend=pytorch
stage=1         # start from 0 if you need to start from data preparation
stop_stage=1   # determine when to stop
ngpu=0         # number of gpus ("0" uses cpu, otherwise use gpu)
debugmode=1
dumpdir=dump   # directory to dump full features
exp=exp
N=0            # number of minibatches to be used (mainly for debugging). "0" uses all minibatches.
verbose=1      # verbose option
seed=1

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
n_average=10 # use 1 for RNN models
recog_model=model.acc.best # set a model to be used for decoding: 'model.acc.best' or 'model.loss.best'

# data - information related to the data
cgn_path=/users/spraak/spchdata/cgn
lang='nl' # dialect
comp='b;f;g;h;i;j;k;l;m;n;o' # components
compname="${comp//;}"
lang="${lang_//;}"

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
train_test=test_${lang}_${compname}_${task}
recog_set=${train_dev}

# Stage 0: preparation of CGN data
if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    ### Task dependent. You have to make data the following preparation part by yourself.
    ### But you can utilize Kaldi recipes in most cases
    echo "stage 0: Data preparation"
    # data preparation of CGN - see: https://github.com/laurensw75/kaldi_egs_CGN/blob/master/s5/local/cgn_data_prep.sh
    cgn_data_prep.sh $cgn_path $lang $comp
fi

# Create two dirs, to dump the train and dev features respectively
feat_tr_dir=${dumpdir}/${train_set}/delta${do_delta}; mkdir -p ${feat_tr_dir}
feat_dt_dir=${dumpdir}/${train_dev}/delta${do_delta}; mkdir -p ${feat_dt_dir}
feat_ts_dir=${dumpdir}/${train_test}/delta${do_delta}; mkdir -p ${feat_ts_dir}

# Stage 1: generating the features
if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    ### Task dependent. You have to design training and dev sets by yourself.
    ### But you can utilize Kaldi recipes in most cases
    echo "stage 1: Feature Generation"
    # Directory relative to current directory to store fbank or mfcc data in. 
    fbankdir=fbank
    ## Generate the fbank features; by default 80-dimensional fbanks with pitch on each frame
    for x in ${train_set} ${train_dev} ${train_test}; do
        echo $x
        ./make_fbank_pitch.sh --cmd "$train_cmd" --nj 10 --write_utt2num_frames true \
            --fbank_config conf/fbank.conf --pitch_config conf/pitch.conf \
            data/${x} exp/make_fbank/${x} ${fbankdir}
        utils/fix_data_dir.sh data/${x}
    done

    compute-cmvn-stats scp:data/${train_set}/feats.scp data/${train_set}/cmvn.ark
    compute-cmvn-stats scp:data/${train_dev}/feats.scp data/${train_dev}/cmvn.ark
    compute-cmvn-stats scp:data/${train_test}/feats.scp data/${train_test}/cmvn.ark

    dump.sh --cmd "$train_cmd" --nj 32 --do_delta ${do_delta} \
        data/${train_set}/feats.scp data/${train_set}/cmvn.ark exp/dump_feats/train ${feat_tr_dir}
    dump.sh --cmd "$train_cmd" --nj 4 --do_delta ${do_delta} --verbose 1 \
        data/${train_dev}/feats.scp data/${train_dev}/cmvn.ark exp/dump_feats/dev ${feat_dt_dir}
    dump.sh --cmd "$train_cmd" --nj 4 --do_delta ${do_delta} --verbose 1 \
	data/${train_test}/feats.scp data/${train_test}/cmvn.ark exp/dump_feats/test ${feat_ts_dir}
fi

# The dictionary (word pieces) that will be generated in stage 2
dict=data/lang_char/train_${lang}_${compname}_${task}_${bpemode}${nbpe}_units.txt
bpemodel=data/lang_char/train_${lang}_${compname}_${task}_${bpemode}${nbpe}

# Stage 2: generating a word-pieces vocabulary
if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    ### Task dependent. You have to check non-linguistic symbols used in the corpus.
    echo "stage 2: Dictionary and Json Data Preparation"
    mkdir -p data/lang_char/
    echo "<unk> 1" > ${dict} # <unk> must be 1, 0 will be used for "blank" in CTC
    cut -f 2- -d " " data/${train_set}/text > data/lang_char/input.txt
    spm_train --input=data/lang_char/input.txt --vocab_size=${nbpe} --model_type=${bpemode} --model_prefix=${bpemodel} --input_sentence_size=100000000
    spm_encode --model=${bpemodel}.model --output_format=piece < data/lang_char/input.txt | tr ' ' '\n' | sort | uniq | awk '{print $0 " " NR+1}' >> ${dict}
    wc -l ${dict}
fi

# the next step is to prepare the json files:
if true ; then
    data2json.sh --feat ${feat_tr_dir}/feats.scp --bpecode ${bpemodel}.model --verbose 1 \
        data/${train_set} ${dict} > ${feat_tr_dir}/data_${bpemode}${nbpe}.json
    data2json.sh --feat ${feat_dt_dir}/feats.scp --bpecode ${bpemodel}.model --verbose 1 \
        data/${train_dev} ${dict} > ${feat_dt_dir}/data_${bpemode}${nbpe}.json
    data2json.sh --feat ${feat_ts_dir}/feats.scp --bpecode ${bpemodel}.model --verbose 1 \
	data/${train_test} ${dict} > ${feat_ts_dir}/data_${bpemode}${nbpe}.json
fi

echo "Finished STAGE 0 to STAGE 2!"

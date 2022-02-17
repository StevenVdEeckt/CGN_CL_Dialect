# CGN_CL_Dialect

Supplementary material to the paper "Continual Learning for Monolingual End-to-End Automatic Speech Recognition" , submitted at EUSIPCO 2022.

This repository is meant to supplement the above paper. It contains the experimental details which should be sufficient to reproduce the results, as well as extra information regarding the results. For any questions, contact steven.vandereeckt@esat.kuleuven.be.



## Data

The Corpus Gesproken Nederlands (CGN) dataset is considered for the experiments. It consists of Dutch speech from the Netherlands (NL) and Belgium (VL), split into fifteen components. In our experiments, we only consider components (b, f, g, h, i, j, k, l, m, o), i.e. we omit those containing spontaneous speech. 
The remaining data is then split into four tasks, considered on the dialect of the speaker. The table below gives a detailed overview. 


Task  | Country | RegionIDs | (Train, Dev, Test) utterances
------------- | ------------- | ------------- | ------------- 
NL-main | Netherlands | regN1, regNx, regX, regZ | (101k, 3k, 3k)
VL-main | Belgium | regV1, regVx, regW, regV4 | (75k, 2k, 2k)
NL-rest | Netherlands | regN2, regN3, regN4 | (68k, 2k, 2k) 
VL-rest | Belgium | regV2, regV3 | (59k, 2k, 2k)

For more information regarding the RegionIDs, see the documentation at https://ivdnt.org/images/stories/producten/documentatie/cgn_website/doc_English/topics/index.htm

For a detailed overview of the utterance IDs and speaker IDs per task and dataset, see the data folder per task. 

### Memory

For the rehearsal-based methods, we sample 500 utterances from the training set and add them to a memory. The data folder also contains the list of utterance IDs for each memory set.


## model 

### word pieces
### config files
### run 

## Hyper-parameters of CL Methods
Following table contains the values of Lambda, the weight of the regularization, for all methods requiring setting Lambda. 'Initial Lambda' refers to the initial value of Lambda which with we started our procedure to determine Lambda (see paper). Final Lambda is the Lambda which came out of this procedure and was used in the experiments. 

Method | Initial Lambda | Final Lambda
| :--- | ---: | ---:
EWC | 1e+05 | 1+e03
MAS | 1e+01 | 1e-01
CSQN | 1e+04 | 1e+02
CSQN-BT | 1e+04 | 1e+02
LWF | 1e+01 | 1e-01 
ER (Lambda) | 1e+00 | 1e-01
KD | 1e+01 | 1e-01


## results

## statistical significance

## references

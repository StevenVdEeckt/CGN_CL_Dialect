# CGN_CL_Dialect

Supplementary material to the paper "Continual Learning for Monolingual End-to-End Automatic Speech Recognition" , submitted at EUSIPCO 2022.

This repository is meant to supplement the above paper. It contains the experimental details which should be sufficient to reproduce the results, as well as extra information regarding the results. For any questions, contact steven.vandereeckt@esat.kuleuven.be.



## data

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

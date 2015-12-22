#!/usr/bin/env python3

import sys
import itertools
import argparse

import spacy.en


from rnn import RNN
from rnn_pos import RNNPOS
from rnn_extended import RNNExtended
from rnn_hierarchical_softmax import RNNHSoftmax
from rnn_hierarchical_softmax_pos import RNNHSoftmaxPOS
from rnn_hierarchical_softmax_grad_clip import RNNHSoftmaxGradClip

from utils import read_vocabulary, tokenize_files, index2word_to_VocabItems
from timeit import default_timer as timer

# Use preprocessed data from:
# http://www.statmt.org/lm-benchmark/1-billion-word-language-modeling-benchmark-r13output.tar.gz
# Contains one sentence tokenized per newline


MIN_WORD_COUNT=5
MAX_SENTENCES = 8000000000 # use all
MAX_LIKELIHOOD_SENTENCES = 10000

def write_vectors(words, rnn, filename):
    with open(filename, 'w') as output_file:
        for i, word in enumerate(words):
            vec = rnn.word_representation_inner(i)
            output_file.write(word[0] + " " + " ".join(str(f) for f in vec) + "\n")

def write_outer_vectors(words, rnn, filename):
    with open(filename, 'w') as output_file:
        for i, word in enumerate(words):
            vec = rnn.word_representation_outer(i)
            output_file.write(word[0] + " " + " ".join(str(f) for f in vec) + "\n")

def debug_sentence(words, sentence):
    print(" ".join(words[index][0] for index in sentence))

def testRNN(args, vocabulary_file, training_dir, testing_dir):
    print("Reading vocabulary " + vocabulary_file + "...")
    words, dictionary = read_vocabulary(vocabulary_file, min_count=MIN_WORD_COUNT)
    print("Vocabulary size: " + str(len(words)) + ", min-count=" + str(MIN_WORD_COUNT))

    print("Reading sentences and training RNN...")
    start = timer()

    if args.model == 'RNN':
        rnn = RNN(len(words), args.nhidden)
        if (args.load_weights and args.export_outer_weights):
            rnn.load(args.load_weights)
            write_outer_vectors(words, rnn, args.export_outer_weights)
            sys.exit(0)
    elif args.model == 'RNNExtended':
        rnn = RNNExtended(len(words), args.nhidden, args.class_size)
    elif args.model == 'RNNHSoftmax':
        vocItems = index2word_to_VocabItems(words)
        rnn = RNNHSoftmax(args.nhidden, vocItems)
    elif args.model == 'RNNHSoftmaxGradClip':
        vocItems = index2word_to_VocabItems(words)
        rnn = RNNHSoftmaxGradClip(args.nhidden, vocItems)
    elif args.model == 'RNNHSoftmaxPOS':
        vocItems = index2word_to_VocabItems(words)
        rnn = RNNHSoftmaxPOS(args.nhidden, vocItems)
    elif args.model == 'RNNPOS':
        rnn = RNNPOS(len(words), args.nhidden)
        if (args.load_weights and args.export_outer_weights):
            rnn.load(args.load_weights)
            write_outer_vectors(words, rnn, args.export_outer_weights)
            sys.exit(0)

    if args.model == 'RNNHSoftmaxPOS' or args.model == 'RNNPOS':
        _NLP = spacy.en.English(parser=False, tagger=True, entity=False)
    else:
        _NLP = None

    
    num_words = 0
    testing_sentences = tokenize_files(dictionary, testing_dir, subsample_frequent=True, nlp=_NLP)
    lik_sentences = [sentence for sentence in itertools.islice(testing_sentences, MAX_LIKELIHOOD_SENTENCES)]
    lr = 0.1
    print("Log-likelihood: %.2f" % (rnn.log_likelihood(lik_sentences)))
    for i in range(args.iter):
        sentences = tokenize_files(dictionary, training_dir, subsample_frequent=True, nlp=_NLP)
        for sentence in itertools.islice(sentences, MAX_SENTENCES):
            rnn.train(sentence, lr=lr)
            num_words += len(sentence)

        print("Iteration " + str(i + 1) + "/" + str(args.iter) + " lr = %.2f" % (lr) + " finished (" + str(num_words) + " words)")
        print("Log-likelihood: %.2f" % (rnn.log_likelihood(lik_sentences)))
        if args.export_file:
            print("- Writing vectors to file " + args.export_file + "...")
            write_vectors(words, rnn, args.export_file + '_' + str(i))
            print("- Dumped")
        num_words = 0

    print("- Took %.2f sec" % (timer() - start))

    #if args.export_file:
    #   print("- Writing vectors to file " + args.export_file + "...")
    #   write_vectors(words, rnn, args.export_file)

    if args.export_weights:
        rnn.export(args.export_weights)
#!/usr/bin/env python3
import itertools
from rnn_extended import RNNExtended
from rnn_extended_relu import RNNExtendedReLU
from utils import read_vocabulary, tokenize_files
from timeit import default_timer as timer

MAX_VOCAB_SIZE = 5000
MAX_SENTENCES = 100
MAX_LIKELIHOOD_SENTENCES = 100
NUM_ITER = 5
HIDDEN_LAYER_SIZE = 20

def testRNN(vocabulary_file, training_dir):
    print("Reading vocabulary " + vocabulary_file + "...")
    words, dictionary = read_vocabulary(vocabulary_file, MAX_VOCAB_SIZE)
    print("Reading sentences and training RNN...")
    start = timer()

    #rnn = RNNExtended(len(words), HIDDEN_LAYER_SIZE)
    rnn = RNNExtendedReLU(len(words), HIDDEN_LAYER_SIZE)

    sentences = tokenize_files(dictionary, training_dir)
    lik_sentences = [sentence for sentence in itertools.islice(sentences, MAX_LIKELIHOOD_SENTENCES)]

    num_words = 0
    for i in range(NUM_ITER):
        sentences = tokenize_files(dictionary, training_dir, remove_stopwords=True)    
        for sentence in itertools.islice(sentences, MAX_SENTENCES):
            # Todo, create context window for each sentence?
            rnn.train(sentence)
            num_words += len(sentence)

        print("Iteration " + str(i + 1) + "/" + str(NUM_ITER) + " finished (" + str(num_words) + " words)")
        print("Log-likelihood: %.2f" % (rnn.log_likelihood(lik_sentences)))
        num_words = 0

    print("- Took %.2f sec" % (timer() - start))

if __name__ == '__main__':
    testRNN("../data/vocabulary/20k.txt", "../data/training/small_1M")
   
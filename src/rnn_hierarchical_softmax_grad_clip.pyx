#!/usr/bin/env python3
import numpy as np
from rnn_hierarchical_softmax import RNNHSoftmax
from rnn_routine import *


class RNNHSoftmaxGradClip(RNNHSoftmax):
    def __init__(self, hidden_layer_size, vocab):
        super(RNNHSoftmaxGradClip, self).__init__(hidden_layer_size, vocab)
        self.grad_threshold = 0.01

    def train(self, Xi, lr=0.1):
        err_hidden = np.empty((self.ntime - 1, self.H))
        for xi, di in zip(Xi, Xi[1:]):
            self.s[1:] = self.s[:-1]
            self.deriv_s[1:] = self.deriv_s[:-1]

            # self.U[:,xi] == self.U.dot(x) if x is one-hot-vector
            self.s[0] = sigmoid(self.U[:,xi] + self.W.dot(self.s[1]))
            self.deriv_s[0] = self.s[0] * (1 - self.s[0])

            err_hidden[0] = np.zeros(self.H)

            # Path for the next word
            classifiers = zip(self.vocab[di].path, self.vocab[di].code)
            for step, code in classifiers:
                p = sigmoid(self.V[step].dot(self.s[0]))
                g = code - p
                err_hidden[0] += g * self.V[step] * self.deriv_s[0]
                der = g * self.s[0]
                self.V[step] += lr * der

            for i in range(1, self.ntime - 1):
                err_hidden[i] = self.W.T.dot(err_hidden[i - 1]) * self.deriv_s[i]

            # The same trick. Instead of updating a whole matrix by err_hidden[0] dot x
            self.U[:, xi] += lr * clip_grad(err_hidden[0], self.grad_threshold)
            self.W += lr * clip_grad(err_hidden.T.dot(self.s[1:]), self.grad_threshold)
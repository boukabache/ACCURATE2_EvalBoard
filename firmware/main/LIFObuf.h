/**
 * @brief Simple LIFO buffer implementation
 * @author Mattia Consani
 * @cite Inspired by the work of Pavel Pervushkin, https://github.com/pervu/FIFObuf
 * 
 * This file contains the implementation of a simple LIFO buffer, in plain C++.
*/

#ifndef LIFOBUF_H
#define LIFOBUF_H

#include <Arduino.h>

template <typename T>
class LIFObuf {
    private:
        int _top;
        size_t _bufferSize;
        T* _buffer;

    public:
        // Constructor
        LIFObuf(size_t bufferSize) {
            _top = 0;
            _bufferSize = bufferSize;
            _buffer = new T[bufferSize];
        }

        // Destructor
        ~LIFObuf() {
            if (_buffer != nullptr) { // Check if the buffer exists
                delete[] _buffer;
            }
        }

        // Push an element to the buffer
        bool push(T element) {
            if (_top < _bufferSize) {
                _buffer[_top++] = element; // Post-increment operator
                return true;
            } else return false;
        }

        // Pop an element from the buffer
        T pop() {
            if (_top > 0) {
                return _buffer[--_top]; // Pre-decrement operator
            } else {
                return T();
            }
        }

        // Overload [] operator
        T& operator[](size_t index) {
            return _buffer[index];
        }

        size_t size() {
            return _top;
        }

        bool empty() {
            return _top == 0;
        }

        bool full() {
            return _top == _bufferSize;
        }

        void clear() {
            _top = 0;
        }
};





#endif // LIFOBUF_H
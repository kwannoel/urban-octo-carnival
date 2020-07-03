;; TODO: import test vectors from Rust and JS libraries, e.g.
;; https://github.com/ethereum/web3.js/blob/master/test/coder.encodeParam.js

(export #t)

(import
  :gerbil/gambit/bytes
  :gerbil/gambit/exceptions
  :std/sugar
  :std/error :std/text/hex :std/test :std/srfi/1
  ../abi ../hex ../types ../ethereum)

(def abi-test
  (test-suite "test suite for glow/ethereum/abi"
    (test-case "contract call encoding"
      ;; Examples from ABI spec
      ;; https://solidity.readthedocs.io/en/develop/abi-spec.html
      (defrule (check-call-encoding name types args strings ...)
        (begin
          (check-equal? (0x<-bytes (bytes<-ethereum-function-call (cons name types) args))
                        (string-append strings ...))
          (check-equal? (ethabi-decode types (bytes<-0x (string-append strings ...)) 4) args)))
      (check-call-encoding "baz" [UInt32 Bool] [69 #t]
                           "0xcdcd77c0"
                           "0000000000000000000000000000000000000000000000000000000000000045"
                           "0000000000000000000000000000000000000000000000000000000000000001")
      ;; TODO: support fixed-size and dynamic-size vectors
      (check-call-encoding "bar" [(Vector Bytes3 2)]
                           [(list->vector (map string->bytes ["abc" "def"]))]
                           "0xfce353f6"
                           "6162630000000000000000000000000000000000000000000000000000000000"
                           "6465660000000000000000000000000000000000000000000000000000000000")
      ;; TODO: support dynamic-size vectors
      (check-call-encoding "sam" [Bytes Bool (Vector UInt256)]
                           [(string->bytes "dave") #t #(1 2 3)]
                           "0xa5643bf2"
                           "0000000000000000000000000000000000000000000000000000000000000060"
                           "0000000000000000000000000000000000000000000000000000000000000001"
                           "00000000000000000000000000000000000000000000000000000000000000a0"
                           "0000000000000000000000000000000000000000000000000000000000000004"
                           "6461766500000000000000000000000000000000000000000000000000000000"
                           "0000000000000000000000000000000000000000000000000000000000000003"
                           "0000000000000000000000000000000000000000000000000000000000000001"
                           "0000000000000000000000000000000000000000000000000000000000000002"
                           "0000000000000000000000000000000000000000000000000000000000000003")
      (check-call-encoding "f" [UInt (Vector UInt32) Bytes10 Bytes]
                           [#x123 #(#x456 #x789) (map string->bytes ["1234567890" "Hello, world!"]) ...]
                           "0x8be65246"
                           "0000000000000000000000000000000000000000000000000000000000000123"
                           "0000000000000000000000000000000000000000000000000000000000000080"
                           "3132333435363738393000000000000000000000000000000000000000000000"
                           "00000000000000000000000000000000000000000000000000000000000000e0"
                           "0000000000000000000000000000000000000000000000000000000000000002"
                           "0000000000000000000000000000000000000000000000000000000000000456"
                           "0000000000000000000000000000000000000000000000000000000000000789"
                           "000000000000000000000000000000000000000000000000000000000000000d"
                           "48656c6c6f2c20776f726c642100000000000000000000000000000000000000")
      (check-call-encoding "g" [(Vector (Vector UInt)) (Vector String)]
                           [#(#(1 2) #(3)) #("one" "two" "three")]
                           "0x2289b18c"
                           "0000000000000000000000000000000000000000000000000000000000000040"
                           "0000000000000000000000000000000000000000000000000000000000000140"
                           "0000000000000000000000000000000000000000000000000000000000000002"
                           "0000000000000000000000000000000000000000000000000000000000000040"
                           "00000000000000000000000000000000000000000000000000000000000000a0"
                           "0000000000000000000000000000000000000000000000000000000000000002"
                           "0000000000000000000000000000000000000000000000000000000000000001"
                           "0000000000000000000000000000000000000000000000000000000000000002"
                           "0000000000000000000000000000000000000000000000000000000000000001"
                           "0000000000000000000000000000000000000000000000000000000000000003"
                           "0000000000000000000000000000000000000000000000000000000000000003"
                           "0000000000000000000000000000000000000000000000000000000000000060"
                           "00000000000000000000000000000000000000000000000000000000000000a0"
                           "00000000000000000000000000000000000000000000000000000000000000e0"
                           "0000000000000000000000000000000000000000000000000000000000000003"
                           "6f6e650000000000000000000000000000000000000000000000000000000000"
                           "0000000000000000000000000000000000000000000000000000000000000003"
                           "74776f0000000000000000000000000000000000000000000000000000000000"
                           "0000000000000000000000000000000000000000000000000000000000000005"
                           "7468726565000000000000000000000000000000000000000000000000000000"))))
;;-*- Gerbil -*-
;; Last point Before Blockchain-End-Point-Projection

(def payForSignature
  (@make-interaction
   start: pc
   end: end

   ;; Entry point for the interaction -- from here on user must be Buyer
   (participant-checkpoint
    pc ;; point B
    (state: (product ;; These are the live variables (published, for the contract)
             (Buyer : uint160)
             (Seller : uint160)
             (digest0 : uint160) ;; digest
             (price : uint96))) ;; price in wei
    balances: ()
    escrows: ()
    next-participant: Buyer
    session-type-of-the-body:
    ((body : () -> pc0)
     (timeout : () -> end))
    body:
    (@ Buyer (deposit! price))
    (pc0 Buyer Seller digest0 price))

   (participant-checkpoint
    pc0
    (state: (product ;; These are the live variables (published, for the contract)
             (Buyer : uint160)
             (Seller : uint160)
             (digest0 : uint160)
             (price : uint96)))
    balances: ((Buyer wei: price))
    escrows: ()
    next-participant: Seller
    session-type-of-the-body:
    ((body : () -> end)
     (timeout : () -> end))
    body:
    (@ Seller (def signature (sign digest0)))
    (@ Seller (publish! signature))
    (def tmp (@app isValidSignature Seller digest0 signature))
    (require! tmp)
    (withdraw! Seller price)
    (end_interaction))

   #|
   ;; implicit end state to every top-level interaction
   (participant-checkpoint
    end
    (state: top)
    balances: ()
    escrows: ()
    next-participant: #f
    session-type-of-the-body:
    ()
    body:))
    |#
  )

#|

            --[t0]->-
           /         \
pc -[f]-> pc0 -[g]-> end
\                    /
 -------[t]----->---/


      A -[f]-> B -[g]-> C -[h]-> D -[i]-> E
      \         \
       [t]       [x]-> K -[y]-> L -[z]-> M
         \->N-[u]--->-/
|#



;; Return from the application-defining interaction.
;; Instead of returning a unit, should it be returning a first-class environment
;; exporting all the variables defined?
(return (@tuple))
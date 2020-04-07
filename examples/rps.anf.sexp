(defdata Hand Rock Paper Scissors)
(def inputHand (λ (tag) (def x : Hand (input Hand tag)) x))
(def NatToHand
     (λ ((x0 : int))
        (def tmp (@app <= 0 x0))
        (def tmp0 (and tmp (@app < x0 3)))
        (require! tmp0)
        (def tmp1 (@app = x0 0))
        (if tmp1 Rock (block (def tmp2 (@app = x0 1)) (if tmp2 Paper Scissors)))))
(def HandToNat (λ ((x1 : Hand)) (switch x1 (Rock 0) (Paper 1) (Scissors 2))))
(defdata Outcome B_Wins Draw A_Wins)
(def inputOutcome (λ (tag0) (def x2 : Outcome (input Outcome tag0)) x2))
(def NatToOutcome
     (λ ((x3 : int))
        (def tmp3 (@app <= 0 x3))
        (def tmp4 (and tmp3 (@app < x3 3)))
        (require! tmp4)
        (def tmp5 (@app = x3 0))
        (if tmp5 B_Wins (block (def tmp6 (@app = x3 1)) (if tmp6 Draw A_Wins)))))
(def OutcomeToNat (λ ((x4 : Outcome)) (switch x4 (B_Wins 0) (Draw 1) (A_Wins 2))))
(def winner
     (λ ((handA : Hand) (handB : Hand))
        :
        Outcome
        (def tmp7 (@app HandToNat handA))
        (def tmp8 (@app HandToNat handB))
        (def tmp9 (@app - 4 tmp8))
        (def tmp10 (@app mod tmp9 3))
        (def tmp11 (@app + tmp7 tmp10))
        (@app NatToOutcome tmp11)))
(@interaction
 ((@list A B))
 (def rockPaperScissors
      (λ (wagerAmount)
         (@ A (def handA0 (@app inputHand "First player, pick your hand")))
         (@ A (def salt (@app randomUInt256)))
         (@ A (@verifiably (def commitment (digest salt handA0))))
         (@ A (publish! commitment))
         (@ A (deposit! wagerAmount))
         (@ B (def handB0 (@app inputHand "Second player, pick your hand")))
         (@ B (publish! handB0))
         (@ B (deposit! wagerAmount))
         (@ A (publish! salt handA0))
         (verify! commitment)
         (def outcome (@app winner handA0 handB0))
         (switch outcome
                 (A_Wins (def tmp12 (@app * 2 wagerAmount)) (withdraw! A tmp12))
                 (B_Wins (def tmp13 (@app * 2 wagerAmount)) (withdraw! B tmp13))
                 (Draw (withdraw! A wagerAmount) (withdraw! B wagerAmount)))
         outcome)))
(@module (@debug-label dlb)
         (defdata Hand Rock Paper Scissors)
         (def Hand1
              (@record (input (λ (tag) (def x (input Hand tag)) x))
                       (toNat (λ (x0)
                                 (switch x0 ((@app-ctor Rock) 0) ((@app-ctor Paper) 1) ((@app-ctor Scissors) 2))))
                       (ofNat (λ (x1)
                                 (switch x1 (0 Rock) (1 Paper) (2 Scissors))))))

         (@debug-label dlb0)
         (defdata Outcome B_Wins Draw A_Wins)
         (def Outcome1
              (@record (input (λ (tag0) (def x2 (input Outcome tag0)) x2))
                       (toNat (λ (x3)
                                 (switch x3 ((@app-ctor B_Wins) 0) ((@app-ctor Draw) 1) ((@app-ctor A_Wins) 2))))
                       (ofNat (λ (x4)
                                 (switch x4 (0 B_Wins) (1 Draw) (2 A_Wins))))))

         (@debug-label dlb1)
         (def winner
              (λ (handA handB)
                 (@debug-label dlb2)
                 (@app (@dot Outcome1 ofNat)
                       (@app mod
                             (@app +
                                   (@app (@dot Hand1 toNat) handA)
                                   (@app - 4 (@app (@dot Hand1 toNat) handB)))
                             3))))

         (@debug-label dlb3)
         (def rockPaperScissors
              (@make-interaction
               ((@list A B))
               (wagerAmount)
               (@debug-label dlb4)
               (@ A (def handA0 (@app (@dot Hand1 input) "First player, pick your hand")))
               (@debug-label dlb5)
               (@ A (def salt (@app randomUInt256)))
               (@debug-label dlb6)
               (@ A (def commitment (digest (@tuple salt handA0))))
               (@debug-label dlb7)
               (publish! A commitment)
               (@debug-label dlb8)
               (deposit! A wagerAmount)

               (@debug-label dlb9)
               (@ B (def handB0 (@app (@dot Hand1 input) "Second player, pick your hand")))
               (@debug-label dlb10)
               (publish! B handB0)
               (@debug-label dlb11)
               (deposit! B wagerAmount)

               (@debug-label dlb12)
               (publish! A salt)
               (publish! A handA0)
               (@debug-label dlb13)
               (require! (== commitment (digest (@tuple salt handA0))))
               (@debug-label dlb14)
               (def outcome (@app winner handA0 handB0))

               (@debug-label dlb15)
               (switch outcome
                       ((@app-ctor A_Wins) (@debug-label dlb16)
                                           (withdraw! A (@app * 2 wagerAmount)))
                       ((@app-ctor B_Wins) (@debug-label dlb17)
                                           (withdraw! B (@app * 2 wagerAmount)))
                       ((@app-ctor Draw) (@debug-label dlb18)
                                         (withdraw! A wagerAmount)
                                         (@debug-label dlb19)
                                         (withdraw! B wagerAmount)))

               (@debug-label dlb20)
               outcome)))

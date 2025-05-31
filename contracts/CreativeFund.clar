;; Constants
(define-constant CREATIVE_FUND_CAPACITY u3000000)
(define-constant BASE_PROJECT_REWARD u20)
(define-constant INNOVATION_BONUS u5)
(define-constant MAX_INNOVATION_LEVEL u6)
(define-constant ERR_INVALID_PROJECT u1)
(define-constant ERR_NO_CREATIVE_CREDITS u2)
(define-constant ERR_FUND_EXCEEDED u3)
(define-constant BLOCKS_PER_MILESTONE u1440)
(define-constant INVESTMENT_MULTIPLIER u4)
(define-constant MIN_INVESTMENT_DURATION u864)
(define-constant EARLY_LIQUIDATION_PENALTY u20)

;; Data Variables
(define-data-var total-creative-credits-issued uint u0)
(define-data-var total-projects uint u0)
(define-data-var creative-director principal tx-sender)

;; Data Maps
(define-map creator-projects principal uint)
(define-map creator-creative-credits principal uint)
(define-map project-start-time principal uint)
(define-map creator-innovation principal uint)
(define-map creator-last-milestone principal uint)
(define-map creator-invested-credits principal uint)
(define-map creator-investment-start-block principal uint)

;; Public Functions

(define-public (launch-creative-project (scope uint))
  (let
    (
      (creator tx-sender)
    )
    (asserts! (> scope u0) (err ERR_INVALID_PROJECT))
    (map-set project-start-time creator burn-block-height)
    (ok true)
  )
)

(define-public (complete-creative-project (scope uint))
  (let
    (
      (creator tx-sender)
      (start-block (default-to u0 (map-get? project-start-time creator)))
      (blocks-worked (- burn-block-height start-block))
      (last-milestone-block (default-to u0 (map-get? creator-last-milestone creator)))
      (innovation-level (default-to u0 (map-get? creator-innovation creator)))
      (capped-innovation (if (<= innovation-level MAX_INNOVATION_LEVEL) innovation-level MAX_INNOVATION_LEVEL))
      (reward-amount (+ BASE_PROJECT_REWARD (* capped-innovation INNOVATION_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-worked scope)) (err ERR_INVALID_PROJECT))
    (map-set creator-projects creator (+ (default-to u0 (map-get? creator-projects creator)) u1))
    (map-set creator-creative-credits creator (+ (default-to u0 (map-get? creator-creative-credits creator)) reward-amount))
    (if (< (- burn-block-height last-milestone-block) BLOCKS_PER_MILESTONE)
      (map-set creator-innovation creator (+ innovation-level u1))
      (map-set creator-innovation creator u1)
    )
    (map-set creator-last-milestone creator burn-block-height)
    (var-set total-projects (+ (var-get total-projects) u1))
    (var-set total-creative-credits-issued (+ (var-get total-creative-credits-issued) reward-amount))
    (asserts! (<= (var-get total-creative-credits-issued) CREATIVE_FUND_CAPACITY) (err ERR_FUND_EXCEEDED))
    (ok reward-amount)
  )
)

(define-public (claim-creative-funding)
  (let
    (
      (creator tx-sender)
      (credit-balance (default-to u0 (map-get? creator-creative-credits creator)))
    )
    (asserts! (> credit-balance u0) (err ERR_NO_CREATIVE_CREDITS))
    (map-set creator-creative-credits creator u0)
    (ok credit-balance)
  )
)

;; Investment Features

(define-public (invest-creative-credits (amount uint))
  (let
    (
      (creator tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_PROJECT))
    (asserts! (>= (var-get total-creative-credits-issued) amount) (err ERR_FUND_EXCEEDED))
    (map-set creator-invested-credits creator amount)
    (map-set creator-investment-start-block creator burn-block-height)
    (var-set total-creative-credits-issued (- (var-get total-creative-credits-issued) amount))
    (ok amount)
  )
)

(define-public (liquidate-invested-credits)
  (let
    (
      (creator tx-sender)
      (invested-amount (default-to u0 (map-get? creator-invested-credits creator)))
      (investment-start-block (default-to u0 (map-get? creator-investment-start-block creator)))
      (blocks-invested (- burn-block-height investment-start-block))
      (penalty (if (< blocks-invested MIN_INVESTMENT_DURATION) (/ (* invested-amount EARLY_LIQUIDATION_PENALTY) u100) u0))
      (final-amount (- invested-amount penalty))
    )
    (asserts! (> invested-amount u0) (err ERR_NO_CREATIVE_CREDITS))
    (map-set creator-invested-credits creator u0)
    (map-set creator-investment-start-block creator u0)
    (var-set total-creative-credits-issued (+ (var-get total-creative-credits-issued) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions

(define-read-only (get-project-count (user principal))
  (default-to u0 (map-get? creator-projects user))
)

(define-read-only (get-creative-credit-balance (user principal))
  (default-to u0 (map-get? creator-creative-credits user))
)

(define-read-only (get-innovation-level (user principal))
  (default-to u0 (map-get? creator-innovation user))
)

(define-read-only (get-creative-fund-stats)
  {
    total-projects: (var-get total-projects),
    total-creative-credits-issued: (var-get total-creative-credits-issued)
  }
)

;; Private Functions

(define-private (is-creative-director)
  (is-eq tx-sender (var-get creative-director))
)
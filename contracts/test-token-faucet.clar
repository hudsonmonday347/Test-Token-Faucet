(define-fungible-token test-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-already-claimed (err u103))
(define-constant err-claim-too-soon (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-faucet-disabled (err u106))
(define-constant err-invalid-recipient (err u107))

(define-data-var token-name (string-ascii 32) "Test Token")
(define-data-var token-symbol (string-ascii 10) "TEST")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var faucet-amount uint u1000000)
(define-data-var claim-cooldown uint u86400)
(define-data-var faucet-enabled bool true)
(define-data-var total-supply uint u0)
(define-data-var max-supply uint u100000000000000)

(define-map last-claim-time principal uint)
(define-map token-balances principal uint)
(define-map allowances {owner: principal, spender: principal} uint)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (who principal))
  (default-to u0 (map-get? token-balances who))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-read-only (get-faucet-amount)
  (var-get faucet-amount)
)

(define-read-only (get-claim-cooldown)
  (var-get claim-cooldown)
)

(define-read-only (is-faucet-enabled)
  (var-get faucet-enabled)
)

(define-read-only (get-last-claim-time (user principal))
  (default-to u0 (map-get? last-claim-time user))
)

(define-read-only (can-claim (user principal))
  (let (
    (last-claim (get-last-claim-time user))
    (current-time burn-block-height)
    (cooldown (var-get claim-cooldown))
  )
    (and 
      (var-get faucet-enabled)
      (>= (- current-time last-claim) cooldown)
    )
  )
)

(define-read-only (time-until-next-claim (user principal))
  (let (
    (last-claim (get-last-claim-time user))
    (current-time burn-block-height)
    (cooldown (var-get claim-cooldown))
    (time-passed (- current-time last-claim))
  )
    (if (>= time-passed cooldown)
      u0
      (- cooldown time-passed)
    )
  )
)

(define-private (mint-tokens (recipient principal) (amount uint))
  (let (
    (current-balance (get-balance recipient))
    (new-balance (+ current-balance amount))
    (current-total (var-get total-supply))
    (new-total (+ current-total amount))
  )
    (asserts! (<= new-total (var-get max-supply)) err-insufficient-balance)
    (var-set total-supply new-total)
    (map-set token-balances recipient new-balance)
    (print {action: "mint", recipient: recipient, amount: amount})
    (ok true)
  )
)

(define-private (burn-tokens (sender principal) (amount uint))
  (let (
    (current-balance (get-balance sender))
    (new-balance (- current-balance amount))
    (current-total (var-get total-supply))
    (new-total (- current-total amount))
  )
    (asserts! (>= current-balance amount) err-insufficient-balance)
    (var-set total-supply new-total)
    (map-set token-balances sender new-balance)
    (print {action: "burn", sender: sender, amount: amount})
    (ok true)
  )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) err-not-token-owner)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (not (is-eq sender recipient)) err-invalid-recipient)
    (let (
      (sender-balance (get-balance sender))
      (recipient-balance (get-balance recipient))
    )
      (asserts! (>= sender-balance amount) err-insufficient-balance)
      (map-set token-balances sender (- sender-balance amount))
      (map-set token-balances recipient (+ recipient-balance amount))
      (print {action: "transfer", sender: sender, recipient: recipient, amount: amount, memo: memo})
      (ok true)
    )
  )
)

(define-public (claim-tokens)
  (let (
    (claimer tx-sender)
    (amount (var-get faucet-amount))
    (current-time burn-block-height)
  )
    (asserts! (var-get faucet-enabled) err-faucet-disabled)
    (asserts! (can-claim claimer) err-claim-too-soon)
    (try! (mint-tokens claimer amount))
    (map-set last-claim-time claimer current-time)
    (print {action: "claim", claimer: claimer, amount: amount, time: current-time})
    (ok amount)
  )
)

(define-public (admin-mint (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (mint-tokens recipient amount)
  )
)

(define-public (admin-burn (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (burn-tokens tx-sender amount)
  )
)

(define-public (set-faucet-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-amount u0) err-invalid-amount)
    (var-set faucet-amount new-amount)
    (print {action: "set-faucet-amount", amount: new-amount})
    (ok true)
  )
)

(define-public (set-claim-cooldown (new-cooldown uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set claim-cooldown new-cooldown)
    (print {action: "set-claim-cooldown", cooldown: new-cooldown})
    (ok true)
  )
)

(define-public (toggle-faucet)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set faucet-enabled (not (var-get faucet-enabled)))
    (print {action: "toggle-faucet", enabled: (var-get faucet-enabled)})
    (ok (var-get faucet-enabled))
  )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set token-uri new-uri)
    (print {action: "set-token-uri", uri: new-uri})
    (ok true)
  )
)

(define-public (approve (spender principal) (amount uint))
  (begin
    (map-set allowances {owner: tx-sender, spender: spender} amount)
    (print {action: "approve", owner: tx-sender, spender: spender, amount: amount})
    (ok true)
  )
)

(define-read-only (get-allowance (owner principal) (spender principal))
  (default-to u0 (map-get? allowances {owner: owner, spender: spender}))
)

(define-public (transfer-from (amount uint) (owner principal) (recipient principal) (memo (optional (buff 34))))
  (let (
    (allowance (get-allowance owner tx-sender))
  )
    (asserts! (>= allowance amount) err-insufficient-balance)
    (map-set allowances {owner: owner, spender: tx-sender} (- allowance amount))
    (transfer amount owner recipient memo)
  )
)

(define-public (revoke-approval (spender principal))
  (begin
    (map-delete allowances {owner: tx-sender, spender: spender})
    (print {action: "revoke-approval", owner: tx-sender, spender: spender})
    (ok true)
  )
)

(define-read-only (get-contract-info)
  {
    name: (var-get token-name),
    symbol: (var-get token-symbol),
    decimals: (var-get token-decimals),
    total-supply: (var-get total-supply),
    max-supply: (var-get max-supply),
    faucet-amount: (var-get faucet-amount),
    claim-cooldown: (var-get claim-cooldown),
    faucet-enabled: (var-get faucet-enabled),
    contract-owner: contract-owner
  }
)

(mint-tokens contract-owner u10000000000)

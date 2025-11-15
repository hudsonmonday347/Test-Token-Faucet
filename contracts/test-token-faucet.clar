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
(define-constant err-invalid-referrer (err u108))
(define-constant err-self-referral (err u109))
(define-constant err-batch-limit-exceeded (err u110))
(define-constant err-batch-empty (err u111))
(define-constant err-vesting-not-found (err u112))
(define-constant err-vesting-locked (err u113))
(define-constant err-vesting-exists (err u114))
(define-constant err-invalid-duration (err u115))
(define-constant err-account-frozen (err u116))

(define-data-var token-name (string-ascii 32) "Test Token")
(define-data-var token-symbol (string-ascii 10) "TEST")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var faucet-amount uint u1000000)
(define-data-var claim-cooldown uint u86400)
(define-data-var faucet-enabled bool true)
(define-data-var total-supply uint u0)
(define-data-var max-supply uint u100000000000000)
(define-data-var referral-bonus uint u100000)
(define-data-var referral-enabled bool true)
(define-data-var batch-limit uint u50)

(define-map last-claim-time principal uint)
(define-map token-balances principal uint)
(define-map allowances {owner: principal, spender: principal} uint)
(define-map referrals principal principal)
(define-map referral-counts principal uint)
(define-map vesting-schedules 
  {beneficiary: principal, schedule-id: uint} 
  {amount: uint, start-block: uint, duration: uint, claimed: uint})
(define-map vesting-count principal uint)
(define-map frozen-accounts principal bool)

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

(define-read-only (get-referrer (user principal))
  (map-get? referrals user)
)

(define-read-only (get-referral-count (referrer principal))
  (default-to u0 (map-get? referral-counts referrer))
)

(define-read-only (get-referral-bonus)
  (var-get referral-bonus)
)

(define-read-only (is-referral-enabled)
  (var-get referral-enabled)
)

(define-read-only (get-batch-limit)
  (var-get batch-limit)
)

(define-read-only (is-frozen (who principal))
  (default-to false (map-get? frozen-accounts who))
)

(define-read-only (get-vesting-schedule (beneficiary principal) (schedule-id uint))
  (map-get? vesting-schedules {beneficiary: beneficiary, schedule-id: schedule-id})
)

(define-read-only (get-vesting-count (beneficiary principal))
  (default-to u0 (map-get? vesting-count beneficiary))
)

(define-read-only (calculate-vested-amount (beneficiary principal) (schedule-id uint))
  (match (get-vesting-schedule beneficiary schedule-id)
    schedule
      (let (
        (current-block burn-block-height)
        (start-block (get start-block schedule))
        (duration (get duration schedule))
        (total-amount (get amount schedule))
        (already-claimed (get claimed schedule))
        (end-block (+ start-block duration))
        (elapsed (if (>= current-block start-block) (- current-block start-block) u0))
      )
        (if (>= current-block end-block)
          (- total-amount already-claimed)
          (let (
            (vested-total (/ (* total-amount elapsed) duration))
          )
            (if (> vested-total already-claimed)
              (- vested-total already-claimed)
              u0))))
    u0)
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
    (asserts! (not (is-frozen sender)) err-account-frozen)
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
    (asserts! (not (is-frozen claimer)) err-account-frozen)
    (asserts! (can-claim claimer) err-claim-too-soon)
    (try! (mint-tokens claimer amount))
    (map-set last-claim-time claimer current-time)
    (print {action: "claim", claimer: claimer, amount: amount, time: current-time})
    (ok amount)
  )
)

(define-public (claim-with-referral (referrer principal))
  (let (
    (claimer tx-sender)
    (amount (var-get faucet-amount))
    (bonus (var-get referral-bonus))
    (current-time burn-block-height)
    (existing-referrer (map-get? referrals claimer))
    (referrer-count (get-referral-count referrer))
  )
    (asserts! (var-get faucet-enabled) err-faucet-disabled)
    (asserts! (var-get referral-enabled) err-faucet-disabled)
    (asserts! (can-claim claimer) err-claim-too-soon)
    (asserts! (not (is-eq claimer referrer)) err-self-referral)
    (asserts! (is-none existing-referrer) err-invalid-referrer)
    (try! (mint-tokens claimer amount))
    (try! (mint-tokens referrer bonus))
    (map-set referrals claimer referrer)
    (map-set referral-counts referrer (+ referrer-count u1))
    (map-set last-claim-time claimer current-time)
    (print {action: "claim-referral", claimer: claimer, referrer: referrer, claim-amount: amount, bonus-amount: bonus, time: current-time})
    (ok {claimed: amount, bonus-paid: bonus})
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

(define-public (set-referral-bonus (new-bonus uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-bonus u0) err-invalid-amount)
    (var-set referral-bonus new-bonus)
    (print {action: "set-referral-bonus", bonus: new-bonus})
    (ok true)
  )
)

(define-public (toggle-referral-system)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set referral-enabled (not (var-get referral-enabled)))
    (print {action: "toggle-referral-system", enabled: (var-get referral-enabled)})
    (ok (var-get referral-enabled))
  )
)

(define-public (set-batch-limit (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-limit u0) err-invalid-amount)
    (var-set batch-limit new-limit)
    (print {action: "set-batch-limit", limit: new-limit})
    (ok true)
  )
)

(define-private (process-batch-transfer (transfer-data {recipient: principal, amount: uint}) (acc (response uint uint)))
  (match acc
    success-val
      (let (
        (recipient (get recipient transfer-data))
        (amount (get amount transfer-data))
        (sender-balance (get-balance tx-sender))
      )
        (if (and 
              (> amount u0)
              (not (is-eq tx-sender recipient))
              (>= sender-balance amount))
          (begin
            (map-set token-balances tx-sender (- sender-balance amount))
            (map-set token-balances recipient (+ (get-balance recipient) amount))
            (ok (+ success-val u1)))
          acc))
    error-val acc)
)

(define-private (process-batch-mint (mint-data {recipient: principal, amount: uint}) (acc (response uint uint)))
  (match acc
    success-val
      (let (
        (recipient (get recipient mint-data))
        (amount (get amount mint-data))
        (mint-result (mint-tokens recipient amount))
      )
        (match mint-result
          mint-success (ok (+ success-val u1))
          mint-error acc))
    error-val acc)
)

(define-public (batch-transfer (transfers (list 50 {recipient: principal, amount: uint})))
  (let (
    (transfers-count (len transfers))
    (batch-max (var-get batch-limit))
    (result (fold process-batch-transfer transfers (ok u0)))
  )
    (asserts! (not (is-frozen tx-sender)) err-account-frozen)
    (asserts! (> transfers-count u0) err-batch-empty)
    (asserts! (<= transfers-count batch-max) err-batch-limit-exceeded)
    (match result
      processed-count
        (begin
          (print {action: "batch-transfer", count: processed-count, total: transfers-count})
          (ok processed-count))
      error-code (err error-code))
  )
)

(define-public (batch-mint (mints (list 50 {recipient: principal, amount: uint})))
  (let (
    (mints-count (len mints))
    (batch-max (var-get batch-limit))
    (result (fold process-batch-mint mints (ok u0)))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> mints-count u0) err-batch-empty)
    (asserts! (<= mints-count batch-max) err-batch-limit-exceeded)
    (match result
      processed-count
        (begin
          (print {action: "batch-mint", count: processed-count, total: mints-count})
          (ok processed-count))
      error-code (err error-code))
  )
)

(define-public (approve (spender principal) (amount uint))
  (begin
    (asserts! (not (is-frozen tx-sender)) err-account-frozen)
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
    (asserts! (not (is-frozen owner)) err-account-frozen)
    (map-set allowances {owner: owner, spender: tx-sender} (- allowance amount))
    (transfer amount owner recipient memo)
  )
)

(define-public (revoke-approval (spender principal))
  (begin
    (asserts! (not (is-frozen tx-sender)) err-account-frozen)
    (map-delete allowances {owner: tx-sender, spender: spender})
    (print {action: "revoke-approval", owner: tx-sender, spender: spender})
    (ok true)
  )
)

(define-public (create-vesting-schedule (beneficiary principal) (amount uint) (duration uint))
  (let (
    (sender-balance (get-balance tx-sender))
    (current-count (get-vesting-count beneficiary))
    (schedule-id (+ current-count u1))
    (start-block burn-block-height)
  )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (not (is-frozen tx-sender)) err-account-frozen)
    (asserts! (>= sender-balance amount) err-insufficient-balance)
    (asserts! (is-none (get-vesting-schedule beneficiary schedule-id)) err-vesting-exists)
    (map-set token-balances tx-sender (- sender-balance amount))
    (map-set vesting-schedules 
      {beneficiary: beneficiary, schedule-id: schedule-id}
      {amount: amount, start-block: start-block, duration: duration, claimed: u0})
    (map-set vesting-count beneficiary schedule-id)
    (print {action: "create-vesting", beneficiary: beneficiary, schedule-id: schedule-id, amount: amount, duration: duration, start-block: start-block})
    (ok schedule-id)
  )
)

(define-public (claim-vested-tokens (schedule-id uint))
  (let (
    (beneficiary tx-sender)
    (vested-amount (calculate-vested-amount beneficiary schedule-id))
    (schedule (unwrap! (get-vesting-schedule beneficiary schedule-id) err-vesting-not-found))
    (current-claimed (get claimed schedule))
    (new-claimed (+ current-claimed vested-amount))
  )
    (asserts! (> vested-amount u0) err-vesting-locked)
    (map-set vesting-schedules
      {beneficiary: beneficiary, schedule-id: schedule-id}
      (merge schedule {claimed: new-claimed}))
    (map-set token-balances beneficiary (+ (get-balance beneficiary) vested-amount))
    (print {action: "claim-vested", beneficiary: beneficiary, schedule-id: schedule-id, amount: vested-amount})
    (ok vested-amount)
  )
)

(define-public (cancel-vesting-schedule (beneficiary principal) (schedule-id uint))
  (let (
    (schedule (unwrap! (get-vesting-schedule beneficiary schedule-id) err-vesting-not-found))
    (total-amount (get amount schedule))
    (already-claimed (get claimed schedule))
    (unvested-amount (- total-amount already-claimed))
    (vested-amount (calculate-vested-amount beneficiary schedule-id))
    (return-amount (- unvested-amount vested-amount))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (if (> vested-amount u0)
      (map-set token-balances beneficiary (+ (get-balance beneficiary) vested-amount))
      true)
    (if (> return-amount u0)
      (map-set token-balances contract-owner (+ (get-balance contract-owner) return-amount))
      true)
    (map-set vesting-schedules
      {beneficiary: beneficiary, schedule-id: schedule-id}
      (merge schedule {claimed: total-amount}))
    (print {action: "cancel-vesting", beneficiary: beneficiary, schedule-id: schedule-id, vested: vested-amount, returned: return-amount})
    (ok {vested-to-beneficiary: vested-amount, returned-to-owner: return-amount})
  )
)

(define-public (freeze-account (who principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set frozen-accounts who true)
    (print {action: "freeze-account", who: who})
    (ok true)
  )
)

(define-public (unfreeze-account (who principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-delete frozen-accounts who)
    (print {action: "unfreeze-account", who: who})
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
    referral-bonus: (var-get referral-bonus),
    referral-enabled: (var-get referral-enabled),
    batch-limit: (var-get batch-limit),
    contract-owner: contract-owner
  }
)

(mint-tokens contract-owner u10000000000)

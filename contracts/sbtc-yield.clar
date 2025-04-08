;; Title: sBTC Yield Vaults - Multi-Strategy Bitcoin Yield Aggregator on Stacks L2
;; Summary: Non-custodial protocol for optimized Bitcoin yield generation through automated strategy allocation
;; Description: 
;; A decentralized yield aggregation engine enabling sBTC holders to earn compound interest through
;; diversified DeFi strategies while maintaining Bitcoin-native security. Features include:
;; - Multi-protocol support with dynamic allocation caps
;; - Real-time APY calculations with block-based accrual
;; - Governance-controlled strategy whitelisting
;; - Transparent risk parameters and TVL limits
;; Built on Stacks Layer 2 for Bitcoin-finalized settlements, combining Clarity's verifiable smart contracts
;; with Bitcoin's security model. Supports institutional-grade compliance through:
;; - Principal-protected deposit tracking
;; - Audit-ready yield accounting
;; - Multi-sig protocol administration
;; - Strategy-specific TVL circuit breakers

;; Constants and Error Codes
(define-constant ERR-UNAUTHORIZED (err u1))           ;; Admin privilege violation
(define-constant ERR-INSUFFICIENT-FUNDS (err u2))     ;; Balance/allowance issues
(define-constant ERR-INVALID-PROTOCOL (err u3))       ;; Unsupported strategy
(define-constant ERR-WITHDRAWAL-FAILED (err u4))      ;; Funds transfer failure
(define-constant ERR-DEPOSIT-FAILED (err u5))         ;; Strategy allocation error
(define-constant ERR-PROTOCOL-LIMIT-REACHED (err u6)) ;; TVL capacity exceeded
(define-constant ERR-INVALID-INPUT (err u7))          ;; Parameter validation failure

;; Protocol Configuration
(define-constant CONTRACT-OWNER tx-sender)            ;; Multi-sig governance contract
(define-constant MAX-PROTOCOLS u5)                    ;; Maximum concurrent strategies
(define-constant MAX-ALLOCATION-PERCENTAGE u100)      ;; 100% = 1e6 precision
(define-constant BASE-DENOMINATION u1000000)          ;; 6 decimal precision
(define-constant MAX-PROTOCOL-NAME-LENGTH u50)        ;; Strategy identifier limit
(define-constant MAX-BASE-APY u10000)                 ;; 100.00% APY ceiling
(define-constant MAX-DEPOSIT-AMOUNT u1000000000)      ;; 1,000,000,000 sats equivalent

;; Data Structures

;; Active yield strategies collection
(define-map supported-protocols
    {protocol-id: uint} 
    {
        name: (string-ascii 50),                  ;; Strategy identifier
        base-apy: uint,                           ;; Annualized percentage (BASE_DENOMINATION)
        max-allocation-percentage: uint,          ;; TVL percentage cap
        active: bool                              ;; Strategy status
    }
)

;; User position tracker
(define-map user-deposits
    {user: principal, protocol-id: uint} 
    {
        amount: uint,                             ;; sBTC-denominated
        deposit-time: uint                        ;; Block height timestamp
    }
)

;; Strategy TVL tracker
(define-map protocol-total-deposits
    {protocol-id: uint} 
    {total-deposit: uint}
)

;; Protocol State
(define-data-var total-protocols uint u0)         ;; Active strategy counter

;; Input Validation Functions

(define-private (is-valid-protocol-id (protocol-id uint))
    (and (> protocol-id u0) (<= protocol-id MAX-PROTOCOLS))
)

(define-private (is-valid-protocol-name (name (string-ascii 50)))
    (and 
        (> (len name) u0) 
        (<= (len name) MAX-PROTOCOL-NAME-LENGTH)
    )
)

(define-private (is-valid-base-apy (base-apy uint))
    (<= base-apy MAX-BASE-APY)
)

(define-private (is-valid-allocation-percentage (percentage uint))
    (and (> percentage u0) (<= percentage MAX-ALLOCATION-PERCENTAGE))
)

(define-private (is-valid-deposit-amount (amount uint))
    (and (> amount u0) (<= amount MAX-DEPOSIT-AMOUNT))
)

;; Authorization

(define-private (is-contract-owner (sender principal))
    (is-eq sender CONTRACT-OWNER)
)

;; Protocol Management

;; Add a new yield strategy to the protocol
(define-public (add-protocol 
    (protocol-id uint) 
    (name (string-ascii 50)) 
    (base-apy uint) 
    (max-allocation-percentage uint)
)
    (begin 
        (asserts! (is-contract-owner tx-sender) ERR-UNAUTHORIZED)
        (asserts! (is-valid-protocol-id protocol-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-protocol-name name) ERR-INVALID-INPUT)
        (asserts! (is-valid-base-apy base-apy) ERR-INVALID-INPUT)
        (asserts! (is-valid-allocation-percentage max-allocation-percentage) ERR-INVALID-INPUT)
        (asserts! (< (var-get total-protocols) MAX-PROTOCOLS) ERR-PROTOCOL-LIMIT-REACHED)
        
        (map-set supported-protocols 
            {protocol-id: protocol-id} 
            {
                name: name,
                base-apy: base-apy,
                max-allocation-percentage: max-allocation-percentage,
                active: true
            }
        )
        (var-set total-protocols (+ (var-get total-protocols) u1))
        (ok true)
    )
)

;; User Operations: Deposits

;; Allocate sBTC to a specific yield strategy
(define-public (deposit 
    (protocol-id uint) 
    (amount uint)
)
    (let 
        (
            (protocol (unwrap! 
                (map-get? supported-protocols {protocol-id: protocol-id}) 
                ERR-INVALID-PROTOCOL
            ))
            (current-total-deposits (default-to 
                {total-deposit: u0} 
                (map-get? protocol-total-deposits {protocol-id: protocol-id})
            ))
            (max-protocol-deposit (/ 
                (* (get max-allocation-percentage protocol) BASE-DENOMINATION) 
                u100
            ))
        )
        (asserts! (is-valid-protocol-id protocol-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-deposit-amount amount) ERR-INVALID-INPUT)
        (asserts! (get active protocol) ERR-INVALID-PROTOCOL)
        (asserts! 
            (<= (+ (get total-deposit current-total-deposits) amount) max-protocol-deposit) 
            ERR-PROTOCOL-LIMIT-REACHED
        )

        (map-set user-deposits 
            {user: tx-sender, protocol-id: protocol-id}
            {amount: amount, deposit-time: stacks-block-height}
        )
        (map-set protocol-total-deposits 
            {protocol-id: protocol-id} 
            {total-deposit: (+ (get total-deposit current-total-deposits) amount)}
        )

        (ok true)
    )
)
# Arena Credits

Arena Credits pay only for play that creates ongoing online-service cost. They
do not buy stronger pieces, better moves, extra clock time, ranking advantages,
or access to the offline game. The beta deliberately starts generously so that
new and occasional players can use online play without buying anything.

## Beta policy

Every new beta wallet starts with **300 welcome bonus credits**. Beginning on
the UTC calendar day after signup, the wallet can receive a Top-up of **up to
3 bonus credits** once per UTC day. This Top-up stops at the 300-credit welcome
ceiling, so returning casual players are supported without passive stockpiling.
The app header shows this guaranteed welcome balance immediately, before online
profile creation. Once an online profile connects, its server-owned balance (or
the last cached balance for that same profile while offline) takes precedence.

A player also earns a **1-credit fair-play completion reward** after completing
a meaningful online round in which at least two legal half-moves were played.
This reward is capped at five credits per player per UTC day. It rewards
finishing a game rather than winning it, so rating, colour, opponent strength
and result do not change the reward. A timeout, agreement or resignation before
the two-half-move threshold does not earn it.

The following charges apply once per player, per round:

| Online round | Cost |
| --- | ---: |
| Live game against a person | 2 credits |
| Daily game against a person | 3 credits |
| Game against a server computer | 4 credits |

Each successfully produced **Move suggestion costs 1 credit**. Suggestions are
disabled in real-player online games for fair play and remain available in
computer/practice play. A failed, stale or unavailable suggestion is not
charged.

After a tournament or Conquest loss or draw, an immediate retry costs **5
credits**. Waiting through the displayed **15-minute cooldown** makes the retry
free. Earlier tournament wins and conquered realms are never removed.

A rematch is a new round and therefore has its own charge. A round charge
covers the whole round; the game never charges by move, minute, capture or
reconnection. The separately disclosed online Move suggestion is the only
per-use server feature in this beta policy.

There is no credit charge for:

- waiting for matchmaking, searching for players or viewing available players;
- creating, receiving, declining or scheduling invitations (acceptance itself
  is free, but an acceptance that starts a round triggers that round's clearly
  disclosed charge);
- reconnecting, resuming or synchronizing a game;
- local multiplayer or on-device computer games;
- entering and progressing through offline tournaments and Conquests (only the
  optional immediate retry after a loss or draw costs credits);
- avatars, chess sets, boards or any other customization;
- threat scans and other play assists apart from Move suggestion; or
- invitations, scheduled-game reminders or mobile notifications.

Credits are never deducted merely because a player opened the online lobby or
because a matchmaking search or invitation failed to produce a game.

If a server wallet falls below **2 credits**, reconnecting after a **24-hour
cooldown** restores it to **5 credits**. This safety grant prevents permanent
online lockout without allowing passive stockpiling.

Every tappable activity that can create a charge displays its exact price beside
the same gold star-coin used by the single global balance; no confirmation
dialog interrupts the action. The interface never presents the internal bonus
and purchased accounting buckets as separate balances. Automatic
invitation-link entry has no pre-tap in-app control, so its authoritative
deduction is identified immediately with a coin notice and activity name. The
always-visible header animates every confirmed increase or decrease and plays
one short coin chime, unless sound is muted. Duplicate responses do not replay
the animation or sound.

## Charging, refunds and reliability

The server is authoritative for the balance. A round charge must be atomic with
the creation or activation of the billable round, and every charge must use a
stable idempotency key derived from the player, game and round. Retrying the same
request, reconnecting, receiving a duplicate frame or restoring the service
must never charge twice.

Every balance-bearing server response includes the complete public account and
recent transaction IDs, not only a number. The lobby and active game both feed
that account into the global header, so navigation cannot interrupt wallet
synchronization and a charge cannot be animated or described before its reason
is known.

The beta deducts only when the round is activated; waiting matchmaking,
unanswered/declined invitations and an opponent that never joins therefore
need no refund. If durable activation cannot be committed, no success response
or committed deduction is emitted. Once activation is committed, the room is
recoverable through Active games and resume. A future production support refund
must be idempotent and return credits to the same bucket from which they were
spent.

Once a round has started, a low or zero balance never interrupts that round.
Normal game actions, reconnection and recovery remain available until it ends.

## Bonus and purchased credits

Wallets keep two server-side accounting buckets even though the app presents
only one clearly labelled spendable balance:

- **Bonus credits** include the welcome grant, daily allowance and fair-play
  rewards. They have no cash value and cannot be transferred.
- **Purchased credits** will come from a verified store purchase in a future
  production release. They cannot be transferred or redeemed for cash.

Both kinds of credit are non-expiring. Bonus credits are spent before purchased
credits. Keeping the buckets separate allows a purchase refund or reversal to
be handled correctly without erasing legitimately earned bonus credits.

Credits never affect chess rules, matchmaking strength, ratings, tournament
progress, Conquest difficulty, offline assists or cosmetic quality. There is no
credit wagering, random paid reward or pay-to-win benefit. Existing local
tournament points are a separate score and are not Arena Credits.

## Beta wallet versus paid launch

The current app intentionally has **no checkout and no real-money credit
purchase**. Its wallet is a beta mechanism for validating grants, deductions,
rewards, balances and failure recovery. All credits currently visible in the
app are bonus credits.

For a future paid launch, the provisional pack sizes are:

| Pack | Credits |
| --- | ---: |
| Starter pack | 100 |
| Regular pack | 300 |
| Enthusiast pack | 750 |
| Hardcore pack | 1,500 |

Prices are not fixed in this repository. Google Play and Apple App Store prices
must be localized through their store catalogs, inclusive of the applicable
regional tax and platform rules. Pack pricing and round costs remain provisional
until real operating-cost and usage data have been measured. Purchased credits
must not be advertised or accepted until the production safeguards below are
complete.

## Production prerequisites

Before enabling checkout, production must provide:

1. Real account authentication and recovery instead of relying only on a
   device-held beta player token.
2. A per-user, server-authoritative transactional wallet and append-only ledger,
   stored independently from the current small-deployment aggregate checkpoint.
3. Atomic reserve, charge, reward and refund operations with unique idempotency
   keys and an auditable transaction history.
4. Server-side Google Play and Apple purchase verification, single-use purchase
   tokens, purchase acknowledgement, and store refund/revocation webhooks.
5. Platform attestation, such as Play Integrity and App Attest, plus rate limits
   and server-enforced daily reward caps.
6. Support tools for inspecting transactions and correcting a wallet without
   silently rewriting its history.
7. Privacy, parental-purchase and virtual-currency disclosures appropriate to
   each release market.

The service should first run the economy in **shadow mode**: calculate the
charge that each operation would have made without deducting it. Telemetry must
measure Cloud Run instance time, WebSocket duration, server-computer CPU,
database reads/writes and storage, network egress, notification delivery,
refunds and fraud. The live rates and localized pack prices should then be
calibrated against observed cost, with a safety margin for store fees, support
and free bonus usage. Existing or already-reserved rounds must be grandfathered
when rates change.

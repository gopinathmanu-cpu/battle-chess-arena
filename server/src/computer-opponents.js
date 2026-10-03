// SPDX-License-Identifier: GPL-3.0-or-later

// These are fictional built-in opponents. Their names are intentionally drawn
// from different parts of the world, while remaining valid Avatar IDs.
const fixedBotLevels = Object.freeze({
  "amina-diallo": 1,
  "lucas-martin": 2,
  "mei-lin": 3,
  "omar-haddad": 4,
  "sofia-rossi": 5,
  "kwame-mensah": 6,
  "ana-costa": 7,
  "priya-nair": 8,
  "diego-alvarez": 9,
  "haruto-sato": 10,
  "nadia-petrova": 11,
  "thandi-ndlovu": 12,
  "noah-williams": 13,
  "fatima-zahra": 14,
  "arjun-mehta": 15,
  "elena-popescu": 16,
  "mateo-silva": 17,
  "min-jun": 18,
  "emma-clarke": 19,
  "ivan-petrov": 20,
});

export const computerOpponents = Object.freeze([
  { id: "amina-diallo", name: "Amina Diallo", avatarId: "bot_amina", level: "beginner" },
  { id: "lucas-martin", name: "Lucas Martin", avatarId: "bot_lucas", level: "beginner" },
  { id: "mei-lin", name: "Mei Lin", avatarId: "bot_mei", level: "beginner" },
  { id: "omar-haddad", name: "Omar Haddad", avatarId: "bot_omar", level: "beginner" },
  { id: "sofia-rossi", name: "Sofia Rossi", avatarId: "bot_sofia", level: "beginner" },
  { id: "kwame-mensah", name: "Kwame Mensah", avatarId: "bot_kwame", level: "beginner" },
  { id: "ana-costa", name: "Ana Costa", avatarId: "bot_ana", level: "beginner" },
  { id: "priya-nair", name: "Priya Nair", avatarId: "bot_priya", level: "intermediate" },
  { id: "diego-alvarez", name: "Diego Alvarez", avatarId: "bot_diego", level: "intermediate" },
  { id: "haruto-sato", name: "Haruto Sato", avatarId: "bot_haruto", level: "intermediate" },
  { id: "nadia-petrova", name: "Nadia Petrova", avatarId: "bot_nadia", level: "intermediate" },
  { id: "thandi-ndlovu", name: "Thandi Ndlovu", avatarId: "bot_thandi", level: "intermediate" },
  { id: "noah-williams", name: "Noah Williams", avatarId: "bot_noah", level: "intermediate" },
  { id: "fatima-zahra", name: "Fatima Zahra", avatarId: "bot_fatima", level: "intermediate" },
  { id: "arjun-mehta", name: "Arjun Mehta", avatarId: "bot_arjun", level: "advanced" },
  { id: "elena-popescu", name: "Elena Popescu", avatarId: "bot_elena", level: "advanced" },
  { id: "mateo-silva", name: "Mateo Silva", avatarId: "bot_mateo", level: "advanced" },
  { id: "min-jun", name: "Min Jun", avatarId: "bot_minjun", level: "advanced" },
  { id: "emma-clarke", name: "Emma Clarke", avatarId: "bot_emma", level: "advanced" },
  { id: "ivan-petrov", name: "Ivan Petrov", avatarId: "bot_ivan", level: "advanced" },
].map((opponent) => Object.freeze({ ...opponent, botLevel: fixedBotLevels[opponent.id] })));

const pieceValue = { p: 100, n: 320, b: 330, r: 500, q: 900, k: 20_000 };

function evaluate(chess, side) {
  if (chess.isCheckmate()) return chess.turn() === side ? -100_000 : 100_000;
  if (chess.isDraw()) return 0;
  let score = 0;
  for (const row of chess.board()) {
    for (const piece of row) {
      if (piece) score += (piece.color === side ? 1 : -1) * pieceValue[piece.type];
    }
  }
  return score;
}

function moveBias(move) {
  const file = move.to.charCodeAt(0) - 97;
  const rank = Number(move.to[1]) - 1;
  const center = 7 - (Math.abs(file - 3.5) + Math.abs(rank - 3.5));
  return center * 2 + (move.captured ? pieceValue[move.captured] / 20 : 0);
}

function replyScore(chess, side) {
  let worst = Number.POSITIVE_INFINITY;
  for (const reply of chess.moves({ verbose: true })) {
    chess.move(reply);
    worst = Math.min(worst, evaluate(chess, side));
    chess.undo();
  }
  return Number.isFinite(worst) ? worst : evaluate(chess, side);
}

/** Select a legal move for either colour at the persona's fixed proficiency. */
export function chooseComputerMove(chess, opponent, random = Math.random) {
  const moves = chess.moves({ verbose: true });
  const side = chess.turn();
  if (moves.length === 0) return null;
  // Resolve the immutable persona, never the human's selected proficiency or
  // an old persisted strength value. Profiles use a computer- ID prefix.
  const personaId = opponent.id.replace(/^computer-/, "");
  const botLevel = fixedBotLevels[personaId];
  if (!botLevel) throw new RangeError(`Unknown computer opponent: ${personaId}`);
  const mistakeChance = (20 - botLevel) / 24;
  if (random() < mistakeChance) return moves[Math.floor(random() * moves.length)];
  const scored = moves.map((move) => {
    chess.move(move);
    const score = botLevel >= 8 ? replyScore(chess, side) : evaluate(chess, side);
    chess.undo();
    return { move, score: score + moveBias(move) };
  });
  scored.sort((a, b) => b.score - a.score);
  return scored[0].move;
}

export function computerProfile(opponent) {
  return {
    id: `computer-${opponent.id}`,
    name: opponent.name,
    avatarId: opponent.avatarId,
    level: opponent.level,
    botLevel: fixedBotLevels[opponent.id],
    computer: true,
    points: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    pointHistory: [],
    sockets: new Set(),
  };
}

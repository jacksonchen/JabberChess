/*
  Stockfish, a chess program for iOS.
  Copyright (C) 2004-2014 Tord Romstad, Marco Costalba, Joona Kiiski.

  Stockfish is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Stockfish is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#import "ECO.h"
#import "Game.h"
#import "GameController.h"
#import "GameParser.h"
#import "Options.h"
#import "PGN.h"

#include "../Chess/san.h"

@implementation Game

@synthesize clock, event, site, date, round, whitePlayer, blackPlayer, result, eco, opening, variation, currentMoveIndex, startPosition, moves, openingString;


/// initWithGameController:FEN: initializes a game from a FEN representing the
/// initial position of the game.

- (id)initWithGameController:(GameController *)gc FEN:(NSString *)fen {
   if (self = [super init]) {
      gameController = gc;
      startFEN = fen;
      currentPosition = new Position;
      startPosition = new Position;
      startPosition->from_fen([fen UTF8String]);
      currentPosition->copy(*startPosition);

      moves = [[NSMutableArray alloc] init];
      currentMoveIndex = 0;

      if (currentPosition->side_to_move() == WHITE) {
         whitePlayer = [[[Options sharedOptions] fullUserName] copy];
         blackPlayer = ENGINE_NAME;
      }
      else {
         whitePlayer = ENGINE_NAME;
         blackPlayer = [[[Options sharedOptions] fullUserName] copy];
      }
      event = @"?";
      // TODO: Decide site by using GPS?
      site = @"?";

      // TODO: Correct date format.
      NSDate *today = [[NSDate alloc] init];
      NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
      [dateFormatter setDateStyle: NSDateFormatterMediumStyle];
      date = [dateFormatter stringFromDate: today];

      round = @"?";
      result = @"*";

      eco = opening = variation = openingString = nil;
      
      if (gc != nil) {
         book = [[OpeningBook alloc] init];
         clock = [[ChessClock alloc] initWithTime: 300000 increment: 0
                                   whiteClockView: [gameController whiteClockView]
                                   blackClockView: [gameController blackClockView]];
         memset(hintHashTable, 0, HINT_HASH_TABLE_SIZE*sizeof(HintHashentry));
      }
   }
   return self;
}


- (id)initWithGameController:(GameController *)gc PGNString:(NSString *)string {
   self = [self initWithGameController: gc];

   GameParser *gp = [[GameParser alloc] initWithString: string];
   PGNToken token[1];
   char name[PGN_STRING_SIZE], value[PGN_STRING_SIZE];

   // Scan for PGN headers first:
   while (YES) {
      [gp getNextToken: token];
      if (token->type != '[') break;
      [gp getNextToken: token];

      if (token->type != TOKEN_SYMBOL)
         [[NSException exceptionWithName: @"PGNHeaderException"
                                  reason: @"Invalid PGN header"
                                userInfo: nil]
            raise];

      strcpy(name, token->string);
      [gp getNextToken: token];

      if (token->type != TOKEN_STRING)
         [[NSException exceptionWithName: @"PGNHeaderException"
                                  reason: @"Invalid PGN header"
                                userInfo: nil]
            raise];

      strcpy(value, token->string);
      [gp getNextToken: token];

      if (token->type != ']')
         [[NSException exceptionWithName: @"PGNHeaderException"
                                  reason: @"Invalid PGN header"
                                userInfo: nil]
            raise];

      // OK, now we have a PGN tag consisting of a (name, value) pair.  Is
      // it one of the tags we care about?
      if (NO) {
      } else if (strcmp(name, "White") == 0) {
         [self setWhitePlayer: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Black") == 0) {
         [self setBlackPlayer: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Event") == 0) {
         [self setEvent: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Site") == 0) {
         [self setSite: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Round") == 0) {
         [self setRound: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Date") == 0) {
         [self setDate: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Result") == 0) {
         [self setResult: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "ECO") == 0) {
         [self setEco: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Opening") == 0) {
         [self setOpening: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Variation") == 0) {
         [self setVariation: [NSString stringWithUTF8String: value]];
      } else if (strncmp(name, "FEN", 3) == 0) {
         startFEN = [NSString stringWithUTF8String: value];
         startPosition->from_fen([startFEN UTF8String]);
         currentPosition->copy(*startPosition);
      }
   }

   int depth = 0;
   do {
      if (token->type == TOKEN_ERROR) {
         [[NSException exceptionWithName: @"PGNException"
         reason: @"Unknown token"
         userInfo: nil] raise];
      } else if (token->type == '{') {
         [self addComment: [gp readComment]];
      } else if (token->type == '(') {
         // Beginning of a RAV.
         depth++;
      } else if (token->type == ')') {
         // End of a RAV.
         depth--;
      } else if (token->type == TOKEN_NAG) {
         // [self addNAG: atoi(token->string)];
      } else if (depth == 0 && token->type == TOKEN_SYMBOL) {
         // This should be a move. Try to parse it:
         Move m = move_from_san(*currentPosition, token->string);
         if (m != MOVE_NONE) {
            UndoInfo u;
            currentPosition->do_move(m, u);
            ChessMove *cm = [[ChessMove alloc] initWithMove: m undoInfo: u];
            [moves addObject: cm];
            currentMoveIndex++;
         }
         else {
            [[NSException exceptionWithName: @"PGNException"
                                     reason: @"Illegal move"
                                   userInfo: nil] raise];
         }
      }
      else if (token->type == TOKEN_RESULT || token->type == TOKEN_EOF) {
         // Finished
         break;
      }
   } while ([gp getNextToken: token]);


   [self computeOpeningString];

   return self;
}


/// init initializes a game to the standard starting position.

- (id)initWithGameController: (GameController *)gc {
   return [self initWithGameController: gc
                                   FEN: @"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"];
}


/// The side to move in the current game position.

- (Color)sideToMove {
   return currentPosition->side_to_move();
}


/// pieceOn: returns the piece on a given square in the current game position.

- (Piece)pieceOn:(Square)sq {
   assert(square_is_ok(sq));
   return currentPosition->piece_on(sq);
}


/// pieceCanMoveFrom: takes a square as input, and returns YES or NO depending
/// on whether the piece on that square in the current position has any legal
/// moves.

- (BOOL)pieceCanMoveFrom:(Square)sq {
   Move mlist[32];

   assert(square_is_ok(sq));
   return currentPosition->moves_from(sq, mlist) > 0;
}


/// destinationSquaresFrom:saveI nArray takes a square and a C array of squares
/// as input, finds all squares the piece on the given square can move to,
/// and stores these possible destination squares in the array. This is used
/// in the GUI in order to highlight the squares a piece can move to.

- (int)movesFrom:(Square)sq saveInArray:(Move *)mlist {
   assert(square_is_ok(sq));
   assert(mlist != NULL);

   return currentPosition->moves_from(sq, mlist);
}

- (int)destinationSquaresFrom:(Square)sq saveInArray:(Square *)sqs {
   Move mlist[32];
   int i, j, n;

   assert(square_is_ok(sq));
   assert(sqs != NULL);

   n = currentPosition->moves_from(sq, mlist);
   for (i = 0, j = 0; i < n; i++)
      // Only include non-promotions and queen promotions, in order to avoid
      // having the same destination squares multiple times in the array.
      if (!move_promotion(mlist[i]) || move_promotion(mlist[i]) == QUEEN)
         sqs[j++] = move_to(mlist[i]);
   sqs[j] = SQ_NONE;
   return j;
}


/// pieceCanMoveFrom:to: takes a source square and a destination square as
/// input, and returns the number of legal moves between the two squares in
/// the current game position. The number of legal moves is usually 0 or 1,
/// but can be more for positions with pawn promotions.

- (int)pieceCanMoveFrom:(Square)fSq to:(Square)tSq {
   Move mlist[32];
   int i, n, count;

   assert(square_is_ok(fSq));
   assert(square_is_ok(tSq));
   n = currentPosition->moves_from(fSq, mlist);
   for (i = 0, count = 0; i < n; i++)
      if (move_to(mlist[i]) == tSq)
         count++;
   return count;
}


/// generateLegalMoves: Generate all legal moves from the current position
/// and saves them in an array. It returns the number of legal moves.

- (int)generateLegalMoves:(Move *)mlist {
   assert(mlist != NULL);
   return currentPosition->all_legal_moves(mlist);
}


/// doMove: takes a move as input, executes the move, and updates the current
/// position and move list.  The move is assumed to be legal.

- (void)doMove:(Move)m {
   UndoInfo u;
   currentPosition->do_move(m, u);
   ChessMove *cm = [[ChessMove alloc] initWithMove: m undoInfo: u];
   if (![self atEnd]) {
      // We are not at the end of the game. We don't want to mess with
      // multiple variations in the game on the iPhone, so we just remove
      // all moves at the end of the move list.
      [moves removeObjectsInRange:
                NSMakeRange(currentMoveIndex, [moves count] - currentMoveIndex)];
   }
   [moves addObject: cm];
   currentMoveIndex++;

   [self computeOpeningString];

   [self pushClock];

   assert([self atEnd]);
}

/// doMoveFrom:to:promotion: takes a source square, a destination square and
/// a piece type representing a promotion as input, finds the matching legal
/// move, and updates the current position and the move list. It is assumed
/// that a single legal move matches the input parameters.

- (Move)doMoveFrom:(Square)fSq to:(Square)tSq promotion:(PieceType)prom {
   assert(square_is_ok(fSq));
   assert(square_is_ok(tSq));
   assert(prom == NO_PIECE_TYPE || (prom >= KNIGHT && prom <= QUEEN));

   // Find the matching move
   Move mlist[32], move = MOVE_NONE;
   int n, i, matches;
   n = currentPosition->moves_from(fSq, mlist);
   for (i = 0, matches = 0; i < n; i++)
      if (move_to(mlist[i]) == tSq && move_promotion(mlist[i]) == prom) {
         move = mlist[i];
         matches++;
      }
   assert(matches == 1);

   // Update position
   UndoInfo u;
   currentPosition->do_move(move, u);

   // Update move list
   ChessMove *cm = [[ChessMove alloc] initWithMove: move undoInfo: u];
   if (![self atEnd]) {
      // We are not at the end of the game. We don't want to mess with
      // multiple variations in the game on the iPhone, so we just remove
      // all moves at the end of the move list.
      [moves removeObjectsInRange:
                NSMakeRange(currentMoveIndex, [moves count] - currentMoveIndex)];
   }
   [moves addObject: cm];
   currentMoveIndex++;

   [self computeOpeningString];

   [self pushClock];

   assert([self atEnd]);

   return move;
}


/// doMoveFrom:to takes a source square and a destination square as input,
/// finds the matching legal move, and updates the current position and the
/// move list. It is assumed that a single legal move matches the input
/// parameters.

- (void)doMoveFrom:(Square)fSq to:(Square)tSq {
   [self doMoveFrom: fSq to: tSq promotion: NO_PIECE_TYPE];
}


/// atBeginning tests whether we are at the beginning of the game.

- (BOOL)atBeginning {
   return currentMoveIndex == 0;
}


/// atEnd tests whether we are at the end of the game.

- (BOOL)atEnd {
   return currentMoveIndex == [moves count];
}


/// takeBack takes back one move from the current position, without deleting
/// the move from the move list. If we are already at the beginning of the
/// game, nothing happens.

- (void)takeBack {
   if (![self atBeginning]) {
      currentMoveIndex--;
      ChessMove *cm = moves[currentMoveIndex];
      Move m = [cm move];
      UndoInfo u = [cm undoInfo];
      currentPosition->undo_move(m, u);
   }
}


/// stepForward steps forward one move in the move list. If we are alread at
/// the end of the move list, nothing happens.

- (void)stepForward {
   if (![self atEnd]) {
      ChessMove *cm = moves[currentMoveIndex];
      Move m = [cm move];
      UndoInfo u = [cm undoInfo];
      currentPosition->do_move(m, u);
      currentMoveIndex++;
   }
}


- (void)toBeginning {
   while (![self atBeginning])
      [self takeBack];
}


- (void)toEnd {
   while (![self atEnd])
      [self stepForward];
}


- (void)toPly:(int)ply {
   [self toBeginning];
   for (int i = 0; i < ply && ![self atEnd]; i++)
      [self stepForward];
}


/// previousMove returns the move made to reach the current position, or nil
/// if we are at the beginning of the game.

- (ChessMove *)previousMove {
   return [self atBeginning]?
      nil :
         moves[currentMoveIndex - 1];
}


/// nextMove returns the next move played in the game from the current
/// position, or nil if we are at the end of the game.

- (ChessMove *)nextMove {
   return [self atEnd]?
      nil : moves[currentMoveIndex];
}


- (NSString *)moveToSAN:(Move)move {
   return [NSString stringWithUTF8String: move_to_san(*currentPosition, move, false).c_str()];
}


/// moveListString returns an NSString representing the entire game in short
/// algebraic notation.

- (NSString *)moveListString {
   Move line[800];
   int i = 0;

   for (ChessMove *move in moves)
      line[i++] = [move move];
   line[i] = MOVE_NONE;
   return [NSString stringWithUTF8String:
                       line_to_san(*startPosition, line, 0, false, 1).c_str()];
}


/// partialMoveListString returns an NSString representing the game up to the
/// current move in short algebraic notation.

- (NSString *)partialMoveListString {
   Move line[800];
   int i = 0;

   for (ChessMove *move in moves) {
      line[i++] = [move move];
      if (i >= currentMoveIndex) break;
   }
   line[i] = MOVE_NONE;
   return [NSString stringWithUTF8String:
                       line_to_san(*startPosition, line, 0, false, 1).c_str()];
}


static NSString* breakLinesInString(NSString *string) {
   NSScanner *scanner = [[NSScanner alloc] initWithString: string];
   NSCharacterSet *charSet =
      [[NSCharacterSet whitespaceCharacterSet] invertedSet];
   NSString *str;
   NSMutableString *mstr;
   NSMutableArray *array = [[NSMutableArray alloc] init];
   NSUInteger i, j;

   // Split 'string' into white-space separated tokens, and store them into
   // 'array':
   while (![scanner isAtEnd]) {
      [scanner scanCharactersFromSet: charSet intoString: &str];
      [array addObject: str];
   }

   // Build new string:
   mstr = [NSMutableString stringWithString: @""];
   j = 0;
   for (i = 0; i < [array count]; i++) {
      NSUInteger length = [array[i] length];
      if (j + length + 1 < 80) {
         if (i > 0) { // HACK
            [mstr appendString: @" "];
            j += length + 1;
         }
         else j += length;
      }
      else {
         [mstr appendString: @"\n"];
         j = length;
      }
      [mstr appendString:array[i]];
   }
   return [NSString stringWithString: mstr];
}

/// pgnMoveListString returns an NSString representing the entire game in short
/// algebraic notation, with line breaks. Used when exporting PGNs.

- (NSString *)pgnMoveListString {
   Move line[800];
   int i = 0;

   for (ChessMove *move in moves)
      line[i++] = [move move];
   line[i] = MOVE_NONE;
   return
      breakLinesInString([NSString
                            stringWithUTF8String:
                               line_to_san(*startPosition, line, 0, false, 1).c_str()]);
}


/// pgnString returns an NSString representing the entire game as PGN.

- (NSString *)pgnString {
   NSMutableString *string = [NSMutableString stringWithCapacity: 2000];
   [string appendFormat: @"[Event \"%@\"]\n", event];
   [string appendFormat: @"[Site \"%@\"]\n", site];
   [string appendFormat: @"[Date \"%@\"]\n", date];
   [string appendFormat: @"[Round \"%@\"]\n", round];
   [string appendFormat: @"[White \"%@\"]\n", whitePlayer];
   [string appendFormat: @"[Black \"%@\"]\n", blackPlayer];
   [string appendFormat: @"[Result \"%@\"]\n", result];
   if (![startFEN isEqualToString: @"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"])
      [string appendFormat: @"[FEN \"%@\"]\n", startFEN];
   [string appendString: @"\n"];
   [string appendString: [self pgnMoveListString]];
   [string appendFormat: @"\n%@\n\n", [self result]];
   return string;
}

/// Jackson's pgnString returns an NSString representing the entire game as PGN from given moveListString instead of using self.pgnMoveListString.

- (NSString *)pgnStringAddToMoveListString:(NSString *)str {
    int ply = currentMoveIndex;
    NSString *modifiedPgnMoveListString;
    if ([self sideToMove] == WHITE)
        modifiedPgnMoveListString = [NSString stringWithFormat:@"%@ %d. %@", [self pgnMoveListString], ply/2+1, str];
    else
        modifiedPgnMoveListString = [NSString stringWithFormat:@"%@ %@", [self pgnMoveListString], str];
    
    NSMutableString *string = [NSMutableString stringWithCapacity: 2000];
    [string appendFormat: @"[Event \"%@\"]\n", event];
    [string appendFormat: @"[Site \"%@\"]\n", site];
    [string appendFormat: @"[Date \"%@\"]\n", date];
    [string appendFormat: @"[Round \"%@\"]\n", round];
    [string appendFormat: @"[White \"%@\"]\n", whitePlayer];
    [string appendFormat: @"[Black \"%@\"]\n", blackPlayer];
    [string appendFormat: @"[Result \"%@\"]\n", result];
    if (![startFEN isEqualToString: @"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"])
        [string appendFormat: @"[FEN \"%@\"]\n", startFEN];
    [string appendString: @"\n"];
    [string appendString: modifiedPgnMoveListString];
    [string appendFormat: @"\n%@\n\n", [self result]];
    return string;
}

/// Jackson: return if a move/pgnString is legal.
- (BOOL)isPgnMoveLegal:(NSString *)str{
    if (str == nil) {
        return FALSE;
    }
    Move m = move_from_san(*currentPosition, [str UTF8String]);
    if (m != MOVE_NONE) {
        return TRUE;
    }else{
        return FALSE;
    }
}


/// emailPgnString is similar to pgnString, but returns a string that can be
/// used as a mailto: URL.

- (NSString *)emailPgnString {
   return
      [[NSString stringWithFormat:
                         @"mailto:%@?subject=&Chess game&body=%@",
                 [[Options sharedOptions] emailAddress],
                 [self pgnString]]
         stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
}


/// uciGameString returns a string representing the game in a format suitable
/// for input to an UCI engine, e.g. "position startpos moves e2e4 e7e5 ..."

- (NSString *)uciGameString {
   NSMutableString *buf = [NSMutableString stringWithCapacity: 4000];

   [buf setString: [NSString stringWithFormat: @"position fen %@", startFEN]];
   if (![self atBeginning]) {
      int i;
      Move m;
      [buf appendString: @" moves"];
      for (i = 0; i < currentMoveIndex; i++) {
         m = [moves[i] move];
         [buf appendFormat: @" %s", move_to_string(m).c_str()];
      }
   }
   return [NSString stringWithString: buf];
}


- (NSString *)htmlString {
   Move line[800];
   int i = 0;

   for (ChessMove *move in moves)
      line[i++] = [move move];
   line[i] = MOVE_NONE;

   NSString *openingDescription =
      (openingString ?
       [NSString stringWithFormat: @"<p><i>%@</i></p>",
                 [openingString stringByReplacingOccurrencesOfString: @"-"
                                                          withString: @"&#8209;"]]
       : @"");

   NSString *moveListString =
      [NSString stringWithUTF8String: // 
                       line_to_html(*startPosition, line,
                                    currentMoveIndex,
                                    [[Options sharedOptions]
                                       figurineNotation]).c_str()];
   return [NSString stringWithFormat: @"%@<p>%@</p>",
                    (((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                      || [UIScreen mainScreen].applicationFrame.size.height > 480) ?
                     openingDescription : @""), 
                    moveListString];
}


- (Move)getBookMove {
   return [book pickMoveForPosition: currentPosition];
}


- (void)getAllBookMoves:(Move *)moveArray {
   [book allMovesForPosition: currentPosition toArray: moveArray];
}


- (NSString *)bookMovesAsString {
   return [book bookMovesAsString: currentPosition];
}


- (Move)moveFromString:(NSString *)string {
   return safe_move_from_string(*currentPosition, [string UTF8String]);
}


- (void)startClock {
   if ([self sideToMove] == WHITE)
      [clock startClockForWhite];
   else
      [clock startClockForBlack];
}


- (void)stopClock {
   [clock stopClock];
}


- (int)whiteRemainingTime {
   return [clock whiteRemainingTime];
}


- (int)blackRemainingTime {
   return [clock blackRemainingTime];
}


- (void)pushClock {
   if (![clock isRunning]) {
      if ([self sideToMove] == WHITE)
         [clock startClockForWhite];
      else
         [clock startClockForBlack];
   }
   else [clock pushClock];
}


- (NSString *)whiteClockString {
   return [clock whiteRemainingTimeString];
}


- (NSString *)blackClockString {
   return [clock blackRemainingTimeString];
}


- (void)setTimeControlWithTime:(int)time increment:(int)increment {
   [clock resetWithTime: time increment: increment];
}


- (void)setTimeControlWithTime:(int)time movesPerSession:(int)mps {
   [clock resetWithTime: time forMoves: mps];
}

- (void)setTimeControlWithFixedTime:(int)time {
   [clock resetWithFixedTime: time];
}


- (void)setHintForCurrentPosition:(Move)hintMove {
   HintHashentry *hhe =
      hintHashTable + (currentPosition->get_key() & (HINT_HASH_TABLE_SIZE-1));
   hhe->key = currentPosition->get_key();
   hhe->move = hintMove;
}


- (Move)getHintForCurrentPosition {
   HintHashentry *hhe =
      hintHashTable + (currentPosition->get_key() & (HINT_HASH_TABLE_SIZE-1));
   if (hhe->key == currentPosition->get_key()) {
      Move mlist[256];
      int n, i;
      n = [self generateLegalMoves: mlist];
      for (i = 0; i < n; i++)
         if (mlist[i] == hhe->move)
            return hhe->move;
   }
   return MOVE_NONE;
}


- (BOOL)positionIsMate {
   return currentPosition->is_mate();
}


- (BOOL)positionIsDraw {
   return currentPosition->is_immediate_draw();
}


- (NSString *)drawReason {
   switch(currentPosition->is_immediate_draw()) {

   case DRAW_MATERIAL:
      return @"No mating material";
   case DRAW_50_MOVES:
      return @"50 non-reversible moves";
   case DRAW_REPETITION:
      return @"Third repetition";
   case DRAW_STALEMATE:
      return @"Stalemate";
   default:
      assert(NO);
      return nil;
   }
}


- (BOOL)positionIsTerminal {
   return [self positionIsMate] || [self positionIsDraw];
}


- (BOOL)positionAfterMoveIsTerminal:(Move)m {
   UndoInfo u;
   BOOL term;
   currentPosition->do_move(m, u);
   term = [self positionIsTerminal];
   currentPosition->undo_move(m, u);
   return term;
}


- (void)addComment:(NSString *)comment {
}


- (Move)currentMove {
   if (currentMoveIndex > 0)
      return [moves[currentMoveIndex - 1] move];
   else
      return MOVE_NONE;
}


- (NSString *)currentFEN {
   return [NSString stringWithUTF8String: currentPosition->to_fen().c_str()];
}


- (NSArray *)moveList {
   NSMutableArray *list = [[NSMutableArray alloc] init];
   Move line[800];
   std::string sanLine[800];
   int i = 0;
   for (ChessMove *move in moves)
      line[i++] = [move move];
   line[i] = MOVE_NONE;
   san_move_list(*startPosition, line, sanLine);
   for (i = 0; line[i] != MOVE_NONE; i++)
      [list addObject: [NSString stringWithUTF8String: sanLine[i].c_str()]];
   return [NSArray arrayWithArray: list];
}


- (uint64_t)keyForCurrentPosition {
   return currentPosition->get_key();
}


- (void)computeOpeningString {
   // Look through the game history backwards in order to find the opening name.
   for (NSInteger i = [moves count]; i >= 0; i--) {
      NSString *s = [[ECO sharedInstance] openingDescriptionForKey:
                                             currentPosition->get_key((int)i)];
      if (s != nil) {
         openingString = s;
         break;
      }
   }
}


- (NSString *)prettyPV:(NSString *)pv
                 depth:(int)depth
                 score:(int)score
             scoreType:(int)scoreType
                  mate:(BOOL)mate {

   Position p(*currentPosition);
   pv = [pv stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
   NSArray *moveStrings = [pv componentsSeparatedByString: @" "];
   NSMutableString *res = [NSMutableString stringWithString: @""];

   // Depth and score
   if (p.side_to_move() == BLACK) {
      score *= -1;
   }
   if (mate) {
      if (scoreType == 0) { // exact score
         [res appendFormat:@"%d %s#%d", depth, score >= 0 ? "+" : "-", abs(score)];
      } else if ((scoreType == 1 && p.side_to_move() == WHITE) ||
            (scoreType == -1 && p.side_to_move() == BLACK)) {
         [res appendFormat:@"%d >%s#%d", depth, score >= 0 ? "+" : "-", abs(score)];
      } else {
         [res appendFormat:@"%d <%s#%d", depth, score >= 0 ? "+" : "-", abs(score)];
      }
   } else {
      if (scoreType == 0) { // exact score
         [res appendFormat:@"%d %s%.1f", depth, score >= 0 ? "+" : "", score / 100.0];
      } else if ((scoreType == 1 && p.side_to_move() == WHITE) ||
            (scoreType == -1 && p.side_to_move() == BLACK)) {
         [res appendFormat:@"%d >%s%.1f", depth, score >= 0 ? "+" : "", score / 100.0];
      } else {
         [res appendFormat:@"%d <%s%.1f", depth, score >= 0 ? "+" : "", score / 100.0];
      }
   }

   // Moves
   BOOL isIpad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
   float screenWidth = [UIScreen mainScreen].applicationFrame.size.width;
   BOOL includeMoveNumbers = screenWidth >= 800.0f || (!isIpad && screenWidth >= 400.0f);
   if (includeMoveNumbers && [self sideToMove] == BLACK) {
      [res appendFormat: @" %d...", currentMoveIndex / 2 + 1];
   }
   int ply = currentMoveIndex;
   for (NSString *s in moveStrings) {
      Move move = safe_move_from_string(p, [s UTF8String]);
      if (move == MOVE_NONE) {
         return nil;
      } else {
         UndoInfo u;
         if (includeMoveNumbers && p.side_to_move() == WHITE) {
            [res appendFormat:@" %d.", ply / 2 + 1];
         } else if (!includeMoveNumbers || ply != currentMoveIndex) {
            [res appendString: @" "];
         }
         [res appendFormat:@"%s", move_to_san(p, move, false).c_str()];
         p.do_move(move, u);
         ply++;
      }
   }
   return res;
}


/// Clean up.

- (void)dealloc {
   NSLog(@"Game dealloc");

   delete startPosition;
   delete currentPosition;

   [clock stopTimer];

}

@end

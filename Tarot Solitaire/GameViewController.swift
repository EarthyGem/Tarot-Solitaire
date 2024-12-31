import UIKit

// MARK: - Card Model
struct Card: Codable, Equatable {
    let suit: String   // "Spades", "Hearts", etc.
    let rank: Int      // 1 (Ace) to 13 (King)
    var isFaceUp: Bool // Tracks whether the card is face-up or face-down
}

// MARK: - Spider Solitaire Game Logic
class SpiderSolitaireGame {
    var deck: [Card] = []
    var tableau: [[Card]] = Array(repeating: [], count: 10)
    var stockpile: [Card] = []
    
    init() {
        setupGame()
    }
    
    func setupGame() {
        // Create a deck of cards with one suit for simplicity
        for _ in 0..<8 { // 8 sets of cards for Spider Solitaire
            for rank in 1...13 {
                deck.append(Card(suit: "Spades", rank: rank, isFaceUp: false))
            }
        }
        
        deck.shuffle()
        
        // Deal cards into tableau
        for i in 0..<10 {
            let numberOfCards = i < 4 ? 6 : 5 // First 4 piles have 6 cards, rest have 5
            tableau[i] = Array(deck.prefix(numberOfCards))
            deck.removeFirst(numberOfCards)
            if !tableau[i].isEmpty {
                tableau[i][tableau[i].count - 1].isFaceUp = true
            }
            
            // Remaining cards go to the stockpile
            stockpile = deck
        }
    }
    
    // MARK: - Card View
    class CardView: UIView {
        let card: Card
        let imageView: UIImageView
        
        init(card: Card) {
            self.card = card
            self.imageView = UIImageView()
            super.init(frame: .zero)
            setupView()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupView() {
            imageView.contentMode = .scaleAspectFit
            imageView.image = UIImage(named: card.isFaceUp ? "\(card.rank)_of_\(card.suit)" : "card_back")
            addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                imageView.topAnchor.constraint(equalTo: topAnchor),
                imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            
            // Add rounded corners and shadow for better visuals
            layer.cornerRadius = 8
            layer.masksToBounds = true
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.3
            layer.shadowOffset = CGSize(width: 2, height: 2)
            layer.shadowRadius = 4
        }
        
        func flipCard() {
            UIView.transition(with: self, duration: 0.3, options: .transitionFlipFromLeft, animations: {
                self.imageView.image = UIImage(named: self.card.isFaceUp ? "\(self.card.rank)_of_\(self.card.suit)" : "card_back")
            }, completion: nil)
        }
    }
    
    // MARK: - Game View Controller
    class GameViewController: UIViewController {
        var game = SpiderSolitaireGame()
        var tableauViews: [UIView] = []
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .green
            
            setupTableau()
            layoutTableau()
            
            // Load saved game state, if available
            loadGameState()
            renderTableau()
        }
        
        func setupTableau() {
            for _ in 0..<10 {
                let pileView = UIView()
                pileView.backgroundColor = .clear
                tableauViews.append(pileView)
                view.addSubview(pileView)
            }
        }
        
        func layoutTableau() {
            let spacing: CGFloat = 10
            let pileWidth: CGFloat = (view.bounds.width - (spacing * 11)) / 10
            
            for (index, pileView) in tableauViews.enumerated() {
                pileView.frame = CGRect(
                    x: spacing + CGFloat(index) * (pileWidth + spacing),
                    y: 100,
                    width: pileWidth,
                    height: view.bounds.height - 200
                )
            }
        }
        
        func renderTableau() {
            for (pileIndex, pileView) in tableauViews.enumerated() {
                pileView.subviews.forEach { $0.removeFromSuperview() }
                
                for (cardIndex, card) in game.tableau[pileIndex].enumerated() {
                    let cardView = CardView(card: card)
                    cardView.frame = CGRect(x: 0, y: CGFloat(cardIndex) * 30, width: pileView.bounds.width, height: 100)
                    pileView.addSubview(cardView)
                    
                    if card.isFaceUp {
                        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleCardDrag(_:)))
                        cardView.addGestureRecognizer(panGesture)
                    }
                }
            }
        }
        
        @objc func handleCardDrag(_ gesture: UIPanGestureRecognizer) {
            guard let cardView = gesture.view as? CardView else { return }
            let translation = gesture.translation(in: view)
            
            switch gesture.state {
            case .changed:
                cardView.center = CGPoint(x: cardView.center.x + translation.x, y: cardView.center.y + translation.y)
                gesture.setTranslation(.zero, in: view)
            case .ended:
                if let targetPileIndex = findValidPile(for: cardView) {
                    moveCard(cardView.card, to: targetPileIndex)
                    checkCompleteSequences()
                    checkWinCondition()
                    saveGameState()
                } else {
                    // Snap card back to original position
                    UIView.animate(withDuration: 0.3) {
                        cardView.frame.origin = cardView.superview?.convert(cardView.frame.origin, to: self.view) ?? .zero
                    }
                }
            default:
                break
            }
        }
        
        func findValidPile(for cardView: CardView) -> Int? {
            for (index, pileView) in tableauViews.enumerated() {
                if pileView.frame.contains(cardView.center) {
                    let pile = game.tableau[index]
                    if canMoveCard(cardView.card, toPile: pile) {
                        return index
                    }
                }
            }
            return nil
        }
        
        func canMoveCard(_ card: Card, toPile pile: [Card]) -> Bool {
            guard let topCard = pile.last else { return true } // Empty pile
            return card.suit == topCard.suit && card.rank == topCard.rank - 1
        }
        
        func moveCard(_ card: Card, to targetPileIndex: Int) {
            guard let sourcePileIndex = game.tableau.firstIndex(where: { $0.contains(card) }),
                  let cardIndex = game.tableau[sourcePileIndex].firstIndex(where: { $0 == card }) else { return }
            
            let movingCards = game.tableau[sourcePileIndex].suffix(from: cardIndex)
            game.tableau[sourcePileIndex].removeLast(movingCards.count)
            game.tableau[targetPileIndex].append(contentsOf: movingCards)
            
            // Flip the new top card in the source pile if any cards remain
            if !game.tableau[sourcePileIndex].isEmpty {
                game.tableau[sourcePileIndex][game.tableau[sourcePileIndex].count - 1].isFaceUp = true
            }
        }
        
        func checkCompleteSequences() {
            for (index, pile) in game.tableau.enumerated() {
                if pile.count >= 13 {
                    let last13 = pile.suffix(13)
                    if isCompleteSequence(cards: Array(last13)) {
                        game.tableau[index].removeLast(13)
                        renderTableau()
                    }
                }
            }
        }
        
        func isCompleteSequence(cards: [Card]) -> Bool {
            guard cards.count == 13 else { return false }
            for i in 0..<cards.count - 1 {
                if cards[i].suit != cards[i + 1].suit || cards[i].rank != cards[i + 1].rank + 1 {
                    return false
                }
            }
            return true
        }
        
        func checkWinCondition() {
            if game.tableau.allSatisfy({ $0.isEmpty }) && game.stockpile.isEmpty {
                showWinScreen()
            }
        }
        
        func showWinScreen() {
            let winLabel = UILabel()
            winLabel.text = "You Win!"
            winLabel.font = UIFont.boldSystemFont(ofSize: 24)
            winLabel.textColor = .white
            winLabel.textAlignment = .center
            winLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            winLabel.layer.cornerRadius = 10
            winLabel.clipsToBounds = true
            winLabel.frame = CGRect(x: 50, y: view.center.y - 50, width: view.frame.width - 100, height: 100)
            view.addSubview(winLabel)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                winLabel.removeFromSuperview()
                self.resetGame()
            }
        }
        
        func resetGame() {
            game = SpiderSolitaireGame()
            renderTableau()
        }
        
        func saveGameState() {
            let encoder = JSONEncoder()
            do {
                let tableauData = try encoder.encode(game.tableau)
                let stockpileData = try encoder.encode(game.stockpile)
                UserDefaults.standard.set(tableauData, forKey: "tableau")
                UserDefaults.standard.set(stockpileData, forKey: "stockpile")
            } catch {
                print("Error saving game state: \(error)")
            }
        }
        
        func loadGameState() {
            let decoder = JSONDecoder()
            do {
                if let tableauData = UserDefaults.standard.data(forKey: "tableau"),
                   let stockpileData = UserDefaults.standard.data(forKey: "stockpile") {
                    game.tableau = try decoder.decode([[Card]].self, from: tableauData)
                    game.stockpile = try decoder.decode([Card].self, from: stockpileData)
                }
            } catch {
                print("Error loading game state: \(error)")
            }
        }
    }
}

# LeitnerSwift

[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-brightgreen.svg)](https://swift.org/package-manager/)

LeitnerSwift is a simple Swift package that implements the Leitner System, a popular algorithm used to aid in spaced repetition for efficient memorization. It manages cards and boxes to ensure that items you struggle with are reviewed more frequently than those you remember easily.

## Features
- **Customizable Boxes**: Specify the number of boxes in your system.
- **Card Management**: Add, update, and review cards as part of the spaced repetition learning system.
- **Flexible Review Scheduling**: The package automatically handles scheduling card reviews based on the box's intervals.

## Installation

### Swift Package Manager (SPM)

To use LeitnerSwift in your project, you can add it as a dependency using Swift Package Manager.

1. Open your project in Xcode.
2. Go to `File > Add Packages...`.
3. Paste the following URL into the search bar:

```arduino
https://github.com/mfsaglam/LeitnerSwift
```

4. Select the version you want to use.

5. Click `Add Package`.

Alternatively, you can add it to your `Package.swift` file:

```swift
dependencies: [
 .package(url: "https://github.com/mfsaglam/LeitnerSwift.git", from: "1.3.7")
]
```


## Usage
### Creating a Leitner System
You can initialize a `LeitnerSystem` with a specific number of boxes. The system will automatically generate review intervals according to the Leitner algorithm.

```swift
import LeitnerSwift

// Create a Leitner system with 5 boxes
let leitnerSystem = LeitnerSystem(boxAmount: 5)
```
### Adding a Card
You can add cards to the system. Cards start in the first box.

```swift
let card = Card(id: UUID(), question: "What is the capital of France?", answer: "Paris")
leitnerSystem.addCard(card)
```

### Updating a Card
After a review session, you can update the card's progress. If the user answers correctly, the card will move to the next box. If not, the card will return to the first box.

```swift
try leitnerSystem.updateCard(card, correct: true)
```
### Reviewing Due Cards
You can fetch cards that are due for review. The method returns cards whose next review date is today or earlier.

```swift
let dueCards = try leitnerSystem.dueForReview(limit: 10)
```


### Loading Boxes
You can also load pre-existing boxes into the system, which is useful for saving and restoring state from persistent storage.

```swift
leitnerSystem.loadBoxes(boxes: existingBoxes)
```


## Contributing
Contributions are welcome! Feel free to open an issue or submit a pull request.

## License
LeitnerSwift is licensed under the MIT License. See the [LICENSE](https://github.com/mfsaglam/LeitnerSwift/blob/main/LICENSE) file for more details.

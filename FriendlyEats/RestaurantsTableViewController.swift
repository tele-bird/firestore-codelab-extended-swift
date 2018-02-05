//
//  Copyright (c) 2016 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit
import FirebaseAuthUI
import FirebaseGoogleAuthUI
import FirebaseFirestore
import SDWebImage

func priceString(from price: Int) -> String {
  let priceText: String
  switch price {
  case 1:
    priceText = "$"
  case 2:
    priceText = "$$"
  case 3:
    priceText = "$$$"
  case _:
    fatalError("price must be between one and three")
  }

  return priceText
}

class RestaurantsTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

  @IBOutlet var tableView: UITableView!
  @IBOutlet var activeFiltersStackView: UIStackView!
  @IBOutlet var stackViewHeightConstraint: NSLayoutConstraint!

  @IBOutlet var cityFilterLabel: UILabel!
  @IBOutlet var categoryFilterLabel: UILabel!
  @IBOutlet var priceFilterLabel: UILabel!

  let backgroundView = UIImageView()

  private var restaurants: [Restaurant] = []
  private var documents: [DocumentSnapshot] = []

  fileprivate var query: Query? {
    didSet {
      if let listener = listener {
        listener.remove()
        observeQuery()
      }
    }
  }

  private var listener: ListenerRegistration?

  fileprivate func observeQuery() {
    guard let query = query else { return }
    stopObserving()

    // Display data from Firestore, part one

    listener = query.addSnapshotListener { [unowned self] (snapshot, error) in
      guard let snapshot = snapshot else {
        print("Error fetching snapshot results: \(error!)")
        return
      }
      let models = snapshot.documents.map { (document) -> Restaurant in
        if let model = Restaurant(document: document) {
          return model
        } else {
          // Don't use fatalError here in a real app.
          fatalError("Unable to initialize type \(Restaurant.self) with dictionary \(document.data())")
        }
      }
      self.restaurants = models
      self.documents = snapshot.documents

      if self.documents.count > 0 {
        self.tableView.backgroundView = nil
      } else {
        self.tableView.backgroundView = self.backgroundView
      }

      self.tableView.reloadData()
    }
  }

  fileprivate func stopObserving() {
    listener?.remove()
  }

  fileprivate func baseQuery() -> Query {
    return Firestore.firestore().restaurants.limit(to: 50)
  }

  lazy private var filters: (navigationController: UINavigationController,
                             filtersController: FiltersViewController) = {
    return FiltersViewController.fromStoryboard(delegate: self)
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    backgroundView.image = UIImage(named: "pizza-monster")!
    backgroundView.contentMode = .scaleAspectFit
    backgroundView.alpha = 0.5
    tableView.backgroundView = backgroundView
    tableView.tableFooterView = UIView()

    // Blue bar with white color
    navigationController?.navigationBar.barTintColor =
      UIColor(red: 0x3d/0xff, green: 0x5a/0xff, blue: 0xfe/0xff, alpha: 1.0)
    navigationController?.navigationBar.isTranslucent = false
    navigationController?.navigationBar.titleTextAttributes =
      [ NSAttributedStringKey.foregroundColor: UIColor.white ]

    tableView.dataSource = self
    tableView.delegate = self
    query = baseQuery()
    stackViewHeightConstraint.constant = 0
    activeFiltersStackView.isHidden = true

    self.navigationController?.navigationBar.barStyle = .black
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.setNeedsStatusBarAppearanceUpdate()
    observeQuery()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    let auth = FUIAuth.defaultAuthUI()!
    if auth.auth?.currentUser == nil {
      auth.providers = []
      present(auth.authViewController(), animated: true, completion: nil)
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    stopObserving()
  }

  @IBAction func didTapPopulateButton(_ sender: Any) {
    // Let's confirm that we want to do this
    let confirmationBox = UIAlertController(title: "Populate the database",
      message: "This will add populate the database with several new restaurants and reviews. Would you like to proceed?",
      preferredStyle: .alert)
    confirmationBox.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    confirmationBox.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
      Firestore.firestore().prepopulate()
    }))
    present(confirmationBox, animated: true)

  }

  @IBAction func didTapClearButton(_ sender: Any) {
    filters.filtersController.clearFilters()
    controller(filters.filtersController, didSelectCategory: nil, city: nil, price: nil, sortBy: nil)
  }

  @IBAction func didTapFilterButton(_ sender: Any) {
    present(filters.navigationController, animated: true, completion: nil)
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    set {}
    get {
      return .lightContent
    }
  }

  deinit {
    listener?.remove()
  }

  // MARK: - UITableViewDataSource

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "RestaurantTableViewCell",
                                             for: indexPath) as! RestaurantTableViewCell
    let restaurant = restaurants[indexPath.row]
    cell.populate(restaurant: restaurant)
    return cell
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return restaurants.count
  }

  // MARK: - UITableViewDelegate

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let controller = RestaurantDetailViewController.fromStoryboard()
    controller.titleImageURL = restaurants[indexPath.row].photoURL
    controller.restaurant = restaurants[indexPath.row]
    controller.restaurantReference = documents[indexPath.row].reference
    self.navigationController?.pushViewController(controller, animated: true)
  }

}

extension RestaurantsTableViewController: FiltersViewControllerDelegate {

  func query(withCategory category: String?, city: String?, price: Int?, sortBy: String?) -> Query {
    var filtered = baseQuery()

    if category == nil && city == nil && price == nil && sortBy == nil {
      stackViewHeightConstraint.constant = 0
      activeFiltersStackView.isHidden = true
    } else {
      stackViewHeightConstraint.constant = 44
      activeFiltersStackView.isHidden = false
    }

    // Advanced queries

    if let category = category, !category.isEmpty {
      filtered = filtered.whereField("category", isEqualTo: category)
    }

    if let city = city, !city.isEmpty {
      filtered = filtered.whereField("city", isEqualTo: city)
    }

    if let price = price {
      filtered = filtered.whereField("price", isEqualTo: price)
    }

    if let sortBy = sortBy, !sortBy.isEmpty {
      filtered = filtered.order(by: sortBy)
    }

    return filtered
  }

  func controller(_ controller: FiltersViewController,
                  didSelectCategory category: String?,
                  city: String?,
                  price: Int?,
                  sortBy: String?) {
    let filtered = query(withCategory: category, city: city, price: price, sortBy: sortBy)

    if let category = category, !category.isEmpty {
      categoryFilterLabel.text = category
      categoryFilterLabel.isHidden = false
    } else {
      categoryFilterLabel.isHidden = true
    }

    if let city = city, !city.isEmpty {
      cityFilterLabel.text = city
      cityFilterLabel.isHidden = false
    } else {
      cityFilterLabel.isHidden = true
    }

    if let price = price {
      priceFilterLabel.text = priceString(from: price)
      priceFilterLabel.isHidden = false
    } else {
      priceFilterLabel.isHidden = true
    }

    self.query = filtered
    observeQuery()
  }

}

class RestaurantTableViewCell: UITableViewCell {

  @IBOutlet private var thumbnailView: UIImageView!

  @IBOutlet private var nameLabel: UILabel!

  @IBOutlet var starsView: ImmutableStarsView!

  @IBOutlet private var cityLabel: UILabel!

  @IBOutlet private var categoryLabel: UILabel!

  @IBOutlet private var priceLabel: UILabel!

  func populate(restaurant: Restaurant) {
    nameLabel.text = restaurant.name
    cityLabel.text = restaurant.city
    categoryLabel.text = restaurant.category
    starsView.rating = Int(restaurant.averageRating.rounded())
    priceLabel.text = priceString(from: restaurant.price)

    let image = restaurant.photoURL
    thumbnailView.sd_setImage(with: image)
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    thumbnailView.sd_cancelCurrentImageLoad()
  }

}
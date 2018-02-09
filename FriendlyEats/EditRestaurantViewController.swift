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
import Firebase
import FirebaseStorage

class EditRestaurantViewController: UIViewController, UINavigationControllerDelegate {
  
  // MARK: Properties
  
  var restaurant: Restaurant?
  var imagePicker = UIImagePickerController()
  var downloadUrl: String?
  
  
  // MARK: Outlets
  
  @IBOutlet weak var restaurantImageView: UIImageView!
  @IBOutlet weak var restaurantNameTextField: UITextField!
  @IBOutlet weak var locationTextField: UITextField!
  @IBOutlet weak var cuisineTextField: UITextField!
  @IBOutlet weak var priceTextField: UITextField!
  
  static func fromStoryboard(_ storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)) -> EditRestaurantViewController {
    let controller = storyboard.instantiateViewController(withIdentifier: "EditRestaurantViewController") as! EditRestaurantViewController
    return controller
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    hideKeyboardWhenTappedAround()
    if let _ = restaurant {
      populateRestaurant()
    }
  }
  
  // populate restaurant with current data
  func populateRestaurant() {
    restaurantNameTextField.text = restaurant?.name
    locationTextField.text = restaurant?.city
    cuisineTextField.text = restaurant?.category
    priceTextField.text = restaurant?.price.description
    restaurantImageView.sd_setImage(with: restaurant?.photoURL)
  }
  
  func saveChanges() {
    var data = [
      "name": restaurantNameTextField.text,
      "city": locationTextField.text,
      "category": cuisineTextField.text,
      "price": Int(priceTextField.text!)
      ] as [String : Any]
    // if photo was changed, add the new url
    if let downloadUrl = downloadUrl {
      data["photoURL"] = downloadUrl
    }
    Firestore.firestore().collection("restaurants").document((restaurant?.documentID)!).updateData(data) { err in
      if let err = err {
        print("Error writing document: \(err)")
      } else {
        self.presentDidSaveAlert()
      }
    }
  }
  
  // MARK: Alert Messages
  
  func presentDidSaveAlert() {
    var message = "Successfully saved!"
    let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    let okAction = UIAlertAction(title: "OK", style: .default) { action in
      self.navigationController?.popViewController(animated: true)
    }
    alertController.addAction(okAction)
    self.present(alertController, animated: true, completion: nil)
  }
  
  func presentWillSaveAlert() {
    let message = "Are you sure you want to save changes to this restaurant?"
    let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    let saveAction = UIAlertAction(title: "Save", style: .default) { action in
      self.saveChanges()
    }
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    alertController.addAction(saveAction)
    alertController.addAction(cancelAction)
    
    self.present(alertController, animated: true, completion: nil)
  }
  
  // If data in text fields isn't valid, give an alert
  func presentInvalidDataAlert(message: String) {
    let title = "Invalid Input"
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    let okAction = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
    alertController.addAction(okAction)
    self.present(alertController, animated: true, completion: nil)
  }
  
  func saveImage(photoData: Data) {
    Storage.storage().reference(withPath: (restaurant?.documentID)!).putData(photoData, metadata: nil) { (metadata, error) in
      if let error = error {
        print(error)
      }
      guard let metadata = metadata else {
        return
      }
      self.downloadUrl = metadata.downloadURL()?.absoluteString
    }
  }
  
  // MARK: Keyboard functionality
  
  @objc func inputToolbarDonePressed() {
    resignFirstResponder()
  }
  
  @objc func keyboardNextButton() {
    if locationTextField.isFirstResponder {
      cuisineTextField.becomeFirstResponder()
    } else if cuisineTextField.isFirstResponder {
      priceTextField.becomeFirstResponder()
    } else if restaurantNameTextField.isFirstResponder {
      locationTextField.becomeFirstResponder()
    } else {
      resignFirstResponder()
    }
  }
  
  @objc func keyboardPreviousButton() {
    if locationTextField.isFirstResponder {
      restaurantNameTextField.becomeFirstResponder()
    } else if cuisineTextField.isFirstResponder {
      locationTextField.becomeFirstResponder()
    } else if priceTextField.isFirstResponder {
      cuisineTextField.becomeFirstResponder()
    } else {
      resignFirstResponder()
    }
  }
  
  lazy var inputToolbar: UIToolbar = {
    let toolbar = UIToolbar()
    toolbar.barStyle = .default
    toolbar.isTranslucent = true
    toolbar.sizeToFit()
    
    var doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(self.inputToolbarDonePressed))
    var flexibleSpaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    var fixedSpaceButton = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
    
    var nextButton  = UIBarButtonItem(image: #imageLiteral(resourceName: "ic_keyboard_arrow_left"), style: .plain, target: self, action: #selector(self.keyboardPreviousButton))
    nextButton.width = 50.0
    var previousButton  = UIBarButtonItem(image: #imageLiteral(resourceName: "ic_keyboard_arrow_right"), style: .plain, target: self, action: #selector(self.keyboardNextButton))
    
    toolbar.setItems([fixedSpaceButton, nextButton, fixedSpaceButton, previousButton, flexibleSpaceButton, doneButton], animated: false)
    toolbar.isUserInteractionEnabled = true
    
    return toolbar
  }()
  
  // MARK: IBActions
  
  @IBAction func selectNewImage(_ sender: Any) {
    selectImage()
  }
  
  @IBAction func didSelectSaveChanges(_ sender: Any) {
    presentWillSaveAlert()
  }
  
}

extension EditRestaurantViewController: UITextFieldDelegate {
  
  func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    textField.inputAccessoryView = inputToolbar
    return true
  }
  
  func textFieldDidEndEditing(_ textField: UITextField) {
    let text = textField.text?.trimmingCharacters(in: .whitespaces)
    if textField == priceTextField {
      if text != "1" && text != "2" && text != "3" {
        // return to previous text
        textField.text = restaurant?.price.description
        presentInvalidDataAlert(message: "Invalid price. Please enter a number from 1 to 3.")
        return
      }
    }
  }
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}

extension EditRestaurantViewController: UIImagePickerControllerDelegate {
  
  func selectImage() {
    imagePicker.delegate = self as? UIImagePickerControllerDelegate & UINavigationControllerDelegate
    if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum){
      
      imagePicker.sourceType = .savedPhotosAlbum;
      imagePicker.allowsEditing = false
      
      self.present(imagePicker, animated: true, completion: nil)
    }
  }
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    
    if let photo = info[UIImagePickerControllerOriginalImage] as? UIImage, let photoData = UIImageJPEGRepresentation(photo, 0.8) {
      saveImage(photoData: photoData)
    }
    self.dismiss(animated: true, completion: nil)
  }
}

extension UIViewController {
  func hideKeyboardWhenTappedAround() {
    let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
    tap.cancelsTouchesInView = false
    view.addGestureRecognizer(tap)
  }
  
  @objc func dismissKeyboard() {
    view.endEditing(true)
  }
}
//
//  ViewController.swift
//  gll-task
//
//  Created by Rostyslav Kobizsky on 5/15/16.
//  Copyright © 2016 Rostyslav Kobizsky. All rights reserved.
//

import UIKit

class RequestBuilderController: UITableViewController {

    lazy var apiURL: NSURL = {
        let urlComponents = NSURLComponents()
        urlComponents.scheme = "https";
        urlComponents.host = "restcountries.eu";
        
        return urlComponents.URL!
    } ()

    lazy var apiClient: HttpClient = {
        return HttpClient(baseURL: self.apiURL)
    } ()
    var method: HttpClient.Method = .GET
    var path: String = "/rest/v1/all"
    var headers = [String: String]()
    var parametes = [String: String]()
    var attachments = [String: NSData]()
    
    @IBAction func sendRequest(sender: AnyObject) {
        if (attachments.count == 0) {
            apiClient.request(method: method,
                              path: path,
                              parameters: parametes,
                              headers: headers,
                              completion: handleResponse)
        } else {
            apiClient.multipartRequest(method: method,
                                       multipart: { (body) in
                                        for (name, data) in self.attachments {
                                            body.appendPart(data, name: name, fileName: "file", mimeType: "image/png")
                                        }
                }, path: path, parameters: parametes, headers: headers, completion: handleResponse)
        }
    }
    
    func handleResponse(data: NSData?, response: NSURLResponse?, error: NSError?) -> Void {
        print("data lenght: \(data?.length), error: \(error)")
        do {
            guard error == nil else {
                print(error!)
                return
            }
            if let data = data, let json: AnyObject = try NSJSONSerialization.JSONObjectWithData(data, options: []) {
                print(json)
            }
        } catch let error as NSError {
            print(error)
        }
    }
}

protocol ReusableCell {
    static var reuseIdentifier: String { get }
}

class ValueCell: UITableViewCell, ReusableCell {
    static var reuseIdentifier: String = "Value Cell"
    @IBOutlet weak var valueTextField: UITextField!
}
class KeyValueCell: UITableViewCell, ReusableCell {
    static var reuseIdentifier: String = "Key Value Cell"
}
class AddNewCell: UITableViewCell, ReusableCell {
    static var reuseIdentifier: String = "Add Cell"
}
class LeftDetailsCell: UITableViewCell, ReusableCell {
    static var reuseIdentifier: String = "Left Details Cell"
}


extension RequestBuilderController {
    
    enum Section: Int {
        case Method = 0
        case Path = 1
        case Headers = 2
        case Parameters = 3
        case Attachments = 4
        
        static var count: Int { return Section.Attachments.hashValue + 1}
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .Method, .Path:    return 1
        case .Headers:          return headers.count + 1
        case .Parameters:       return parametes.count + 1
        case .Attachments:      return attachments.count + 1
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        switch Section(rawValue: indexPath.section)! {
        case .Method:
            cell = tableView.dequeueReusableCellWithIdentifier(LeftDetailsCell.reuseIdentifier)!
            cell.textLabel?.text = NSLocalizedString("Method", comment: "")
            cell.detailTextLabel?.text = method.description
            break
        case .Path:
            cell = tableView.dequeueReusableCellWithIdentifier(ValueCell.reuseIdentifier)!
            (cell as! ValueCell).valueTextField.text = path
            break
        case .Headers:
            if (headers.count == indexPath.row) {
                cell = tableView.dequeueReusableCellWithIdentifier(AddNewCell.reuseIdentifier)!
            } else {
                cell = tableView.dequeueReusableCellWithIdentifier(KeyValueCell.reuseIdentifier)!
                let key = [String] (headers.keys) [indexPath.row]
                (cell as! KeyValueCell).textLabel!.text = key
                (cell as! KeyValueCell).detailTextLabel!.text = headers[key]
            }
            break
        case .Parameters:
            if (parametes.count == indexPath.row) {
                cell = tableView.dequeueReusableCellWithIdentifier(AddNewCell.reuseIdentifier)!
            } else {
                cell = tableView.dequeueReusableCellWithIdentifier(KeyValueCell.reuseIdentifier)!
                let key = [String] (parametes.keys) [indexPath.row]
                (cell as! KeyValueCell).textLabel!.text = key
                (cell as! KeyValueCell).detailTextLabel!.text = parametes[key]
            }
            break
        case .Attachments:
            if (attachments.count == indexPath.row) {
                cell = tableView.dequeueReusableCellWithIdentifier(AddNewCell.reuseIdentifier)!
            } else {
                cell = tableView.dequeueReusableCellWithIdentifier(KeyValueCell.reuseIdentifier)!
                let key = [String] (attachments.keys) [indexPath.row]
                (cell as! KeyValueCell).textLabel!.text = key
                (cell as! KeyValueCell).detailTextLabel!.text = String(attachments[key]?.length)
            }
            break
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .Method:
            let controller = AllowedMethodsController()
            controller.didSelect = {(method: HttpClient.Method) -> Void in
                self.method = method
                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            }
            navigationController?.pushViewController(controller, animated: true)
        default:
            let cell = tableView.cellForRowAtIndexPath(indexPath)
            switch cell {
            case is ValueCell:
                (cell as! ValueCell).valueTextField.becomeFirstResponder()
                break
            case is AddNewCell:
                addNew(Section(rawValue: indexPath.section)!)
                break
            default:
                break
            }
            break
        }
    }
    
    func addNew(section: Section) {
        let alert = UIAlertController(title: NSLocalizedString("Input Key & Value", comment: ""),
                                      message: nil,
                                      preferredStyle: .Alert)
        alert.addTextFieldWithConfigurationHandler { (textFiled) in
            textFiled.placeholder = NSLocalizedString("Key", comment: "")
        }
        alert.addTextFieldWithConfigurationHandler { (textFiled) in
            textFiled.placeholder = NSLocalizedString("Value", comment: "")
        }

        var handler: ((UIAlertAction) -> Void)?
        switch section {
        case .Headers:
            handler = { (action) in
                if let key = alert.textFields?.first?.text {
                    let value = alert.textFields?.last?.text
                    self.headers[key] = value
                    self.tableView.reloadData()
                }
            }
            break
        case .Parameters:
            handler = { (action) in
                if let key = alert.textFields?.first?.text {
                    let value = alert.textFields?.last?.text
                    self.parametes[key] = value
                    self.tableView.reloadData()
                }
            }
            break
        case .Attachments:

            break
        default: return
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Add", comment: ""), style: .Default, handler: handler))
        presentViewController(alert, animated: true, completion: nil)
    }
}

class AllowedMethodsController: UITableViewController {
    var didSelect: ((method: HttpClient.Method) -> Void)?
    override func viewDidLoad() {
        self.title = NSLocalizedString("Allowed Methods", comment: "")
    }
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return HttpClient.Method.count
    }
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let identifier = "Method Cell"
        var cell = tableView.dequeueReusableCellWithIdentifier(identifier)
        if cell == nil {
            cell = UITableViewCell(style: .Default, reuseIdentifier: identifier)
        }
        cell!.textLabel?.text = HttpClient.Method(rawValue: indexPath.row)?.description
        return cell!
    }
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        didSelect?(method: HttpClient.Method(rawValue: indexPath.row)!)
        navigationController?.popViewControllerAnimated(true)
    }
}
//
//  BrowseSearchTableViewController.swift
//  Volumio
//
//  Created by Federico Sintucci on 22/10/16.
//  Copyright © 2016 Federico Sintucci. All rights reserved.
//

import UIKit

class BrowseSearchTableViewController: UITableViewController, UISearchBarDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    
    var sourcesList : [SearchResultObject] = []
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerObservers()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        localize()

        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        searchBar.delegate = self

        refreshControl?.addTarget(self,
            action: #selector(handleRefresh),
            for: UIControlEvents.valueChanged
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        clearAllNotice()
        
        NotificationCenter.default.removeObserver(self)
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(updateSources(notification:)),
            name: .browseSearch,
            object: nil
        )
        NotificationCenter.default.addObserver(self,
            selector: #selector(isOnPlaylist(notification:)),
            name: .addedToPlaylist,
            object: nil
        )
    }

    func updateSources(notification: NSNotification) {
        guard let sources = notification.object as? [SearchResultObject] else { return }
        
        sourcesList = sources
        tableView.reloadData()
        clearAllNotice()
    }
    
    func isOnPlaylist(notification:NSNotification) {
        self.clearAllNotice()
        
        guard let object = notification.object else { return }
        
        noticeTop("Added to \(object)", autoClear: true, autoClearTime: 3)
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sourcesList.count
    }
    
    override func tableView(_ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        let sections = sourcesList[section]
        if let items = sections.items {
            return items.count
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        
        let itemList = sourcesList[indexPath.section]
        let item = itemList.items![indexPath.row] as LibraryObject
        
        if item.type == "song" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "track", for: indexPath) as! TrackTableViewCell
            
            cell.trackTitle.text = item.title ?? ""
            let artist = item.artist ?? ""
            let album = item.album ?? ""
            cell.trackArtist.text = "\(artist) - \(album)"
            
            if item.albumArt?.range(of:"http") != nil{
                cell.trackImage.contentMode = .scaleAspectFill
                cell.trackImage.kf.setImage(with: URL(string: item.albumArt!), placeholder: UIImage(named: "background"), options: [.transition(.fade(0.2))])
            } else {
                
                if let artist = item.artist, let album = item.album {
                    LastFmManager.sharedInstance.getAlbumArt(artist: artist, album: album, completionHandler: { (albumUrl) in
                        if let albumUrl = albumUrl {
                            DispatchQueue.main.async {
                                cell.trackImage.contentMode = .scaleAspectFill
                                cell.trackImage.kf.setImage(with: URL(string: albumUrl), placeholder: UIImage(named: "background"), options: [.transition(.fade(0.2))])
                            }
                        }
                    })
                }
            }
            
            return cell
            
        } else if item.type == "webradio" || item.type == "mywebradio" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "radio", for: indexPath) as! FolderTableViewCell
            
            cell.folderTitle.text = item.title ?? ""
            if item.albumArt?.range(of:"http") != nil{
                cell.folderImage.contentMode = .scaleAspectFill
                cell.folderImage.kf.setImage(with: URL(string: item.albumArt!), placeholder: UIImage(named: "radio"), options: [.transition(.fade(0.2))])
            } else {
                cell.folderImage.contentMode = .center
                cell.folderImage.image = UIImage(named: "radio")
            }
            return cell
            
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "folder", for: indexPath) as! FolderTableViewCell
            
            cell.folderTitle.text = item.title ?? ""
            if item.albumArt?.range(of:"http") != nil{
                cell.folderImage.contentMode = .scaleAspectFill
                cell.folderImage.kf.setImage(with: URL(string: item.albumArt!), placeholder: UIImage(named: "folder"), options: [.transition(.fade(0.2))])
            } else {
                cell.folderImage.contentMode = .center
                cell.folderImage.image = UIImage(named: "folder")
            }
            return cell
            
        }
    }
    
    override func tableView(_ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        return sourcesList[section].title
    }
    
    override func tableView(_ tableView: UITableView,
        commit editingStyle: UITableViewCellEditingStyle,
        forRowAt indexPath: IndexPath
    ) {
    }
    
    override func tableView(_ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath
    ) -> [UITableViewRowAction]? {
        
        let itemList = sourcesList[indexPath.section]
        let item = itemList.items![indexPath.row] as LibraryObject
        
        // TODO: L18N
        let play = UITableViewRowAction(style: .normal, title: "Play") { action, index in
            SocketIOManager.sharedInstance.addAndPlay(uri:item.uri!, title: item.title!, service: item.service! )
            tableView.setEditing(false, animated: true)
        }
        play.backgroundColor = UIColor(red: 74.0/255.0, green: 190.0/255.0, blue: 134.0/255.0, alpha: 1)
        
        // TODO: L18N
        let more = UITableViewRowAction(style: .normal, title: "More") { action, index in
            self.playlistActions(item: item)
            tableView.setEditing(false, animated: true)
        }
        more.backgroundColor = UIColor(red: 76.0/255.0, green: 71.0/255.0, blue: 70.0/255.0, alpha: 1)
        
        return [more, play]
    }
    
    override func tableView(_ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        return 54.0
    }
    
    func handleRefresh(refreshControl: UIRefreshControl) {
        guard let text = searchBar.text else {
            refreshControl.endRefreshing()
            return
        }
        SocketIOManager.sharedInstance.browseSearch(text: text)
        refreshControl.endRefreshing()
    }
    
    func playlistActions(item:LibraryObject) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        // TODO: L18N
        alert.addAction(
            UIAlertAction(title: "Play", style: .default, handler: { (action) in
                SocketIOManager.sharedInstance.addAndPlay(uri: item.uri!, title: item.title!, service: item.service!)
            })
        )
        // TODO: L18N
        alert.addAction(
            UIAlertAction(title: "Add to queue", style: .default, handler: { (action) in
                SocketIOManager.sharedInstance.addToQueue(uri: item.uri!, title: item.title!, service: item.service!)
            })
        )
        // TODO: L18N
        alert.addAction(
            UIAlertAction(title: "Clear and Play", style: .default, handler: { (action) in
                SocketIOManager.sharedInstance.clearAndPlay(uri: item.uri!, title: item.title!, service: item.service!)
            })
        )
        // TODO: L18N
        alert.addAction(
            UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        )
        self.present(alert, animated: true, completion: nil)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.pleaseWait()
        SocketIOManager.sharedInstance.browseSearch(text: searchBar.text!)
        searchBar.resignFirstResponder()
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "browseFolder" {
            guard let indexPath = self.tableView.indexPathForSelectedRow else { return }
                
            let itemList = sourcesList[indexPath.section]
            let item = itemList.items![indexPath.row] as LibraryObject
            
            let destinationController = segue.destination as! BrowseFolderTableViewController
            destinationController.serviceName = item.title
            destinationController.serviceUri = item.uri
            destinationController.serviceType = item.type
            destinationController.serviceService = item.service
        }
    }
}

// MARK: - Localization

extension BrowseSearchTableViewController {
    
    fileprivate func localize() {
        navigationItem.title = NSLocalizedString("BROWSE_SEARCH",
            comment: "browse search view title"
        )
    }

}

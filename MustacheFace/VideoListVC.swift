//
//  VideoListVC.swift
//  MustacheFace
//
//  Created by 曹越程 on 2023/8/19.
//

import UIKit
import CoreData
import AVKit
import AVFoundation

class VideoListVC: UITableViewController {
        
    var videos: [VideoEntity] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = self.editButtonItem
        tableView.backgroundColor = UIColor.white
        tableView.allowsSelectionDuringEditing = true
        fetchVideosFromCoreData()

        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = 100
        tableView.register(VideoCell.nib(), forCellReuseIdentifier: VideoCell.identifier)
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source
    
    func fetchVideosFromCoreData() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<VideoEntity> = VideoEntity.fetchRequest()
        do {
            videos = try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch videos: \(error)")
        }
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return videos.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let video = videos[indexPath.row]
        if tableView.isEditing {
            let alertController = UIAlertController(title: "Edit Tag", message: "Enter the new tag", preferredStyle: .alert)
            
            alertController.addTextField { (textField) in
                textField.text = "" // fetch current tag for the selected recording
            }
            
            let saveAction = UIAlertAction(title: "Save", style: .default) { [weak alertController] _ in
                if let newText = alertController?.textFields?[0].text {
                    // Assuming you have a managedObjectContext variable available
                    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
                    
                    let fetchRequest: NSFetchRequest<VideoEntity> = VideoEntity.fetchRequest() // Use your entity name here
                    fetchRequest.predicate = NSPredicate(format: "videoURL == %@", video.videoURL ?? "")
                    
                    do {
                        let results = try context.fetch(fetchRequest)
                        if let videoToUpdate = results.first {
                            videoToUpdate.tag = newText // Assuming the tag attribute is named "tag"
                            
                            // Save the context
                            try context.save()
                        }
                    } catch {
                        print("Failed to fetch or save the edited video: \(error)")
                    }

                    tableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            
            alertController.addAction(saveAction)
            alertController.addAction(cancelAction)
            
            present(alertController, animated: true, completion: nil)
            
            tableView.deselectRow(at: indexPath, animated: true)
        }
        else{
            guard let videoURLString = video.videoURL, let url = URL(string: videoURLString) else {
                print("Invalid video URL.")
                return
            }
            
            // Create an AVPlayer instance with the video URL
            let player = AVPlayer(url: url)
            
            // Initialize and present AVPlayerViewController
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            self.present(playerViewController, animated: true) {
                // Auto-play the video when the player view controller is presented
                playerViewController.player?.play()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VideoCell.identifier, for: indexPath) as! VideoCell
        let video = videos[indexPath.row]
        cell.configure(video: video)
        return cell
    }
    
    func configureTableView() {
        view.addSubview(UITableView())
    }
    
    

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the video entity from Core Data
            let videoToDelete = videos[indexPath.row]
            do {
                try FileManager.default.removeItem(at: URL(string: videoToDelete.videoURL!)!)
            } catch {
                print("Error deleting video file: \(error)")
            }
            let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
            context.delete(videoToDelete)
            
            do {
                try context.save()
            } catch {
                print("Error saving after deleting video: \(error)")
            }
            
            // Delete the video entity from the videos array
            videos.remove(at: indexPath.row)
            
            // Delete the cell from the table view
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
}

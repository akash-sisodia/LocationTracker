//
//  AlertView.swift
//
//  Copyright © 2020 Codiant Software Technologies Pvt Ltd. All rights reserved.
//

import UIKit

class AlertView: UIView {
    
    @IBOutlet weak var alertBgView: UIView!
    @IBOutlet weak var dialogView: UIView!
    @IBOutlet weak var lblAlartMessage: UILabel!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnOk: UIButton!
    var callBack: ((Int) -> ())?
    
    static func show(message: String?, isDismissOnly: Bool?, dismissTitle: String?, cancelTitle: String?, okTitle: String?, callBack: ((Int?) ->
        ())? = nil) {
        DispatchQueue.main.async {
            let nib = UINib(nibName: "AlertView", bundle: nil)
            let alertView = nib.instantiate(withOwner: nil, options: nil)[0] as! AlertView
            alertView.frame = UIScreen.main.bounds
            if let keyWindow = UIApplication.shared.keyWindow {
              keyWindow.addSubview(alertView)
            }
            //UIApplication.shared.keyWindow?.rootViewController?.view.addSubview(alertView)

            alertView.callBack = callBack
            alertView.btnOk.setTitle(okTitle ?? "Ok", for: .normal)
            alertView.btnCancel.setTitle(cancelTitle ?? "Cancel", for: .normal)
            alertView.btnDismiss.setTitle(dismissTitle ?? "Dismiss", for: .normal)
            
            if isDismissOnly == true{
                alertView.btnOk.isHidden = true
                alertView.btnCancel.isHidden = true
                alertView.btnDismiss.isHidden = false
                alertView.btnCancel.isUserInteractionEnabled = false
                alertView.btnOk.isUserInteractionEnabled = false
                alertView.btnDismiss.isUserInteractionEnabled = true
            }else{
                alertView.btnOk.isHidden = false
                alertView.btnCancel.isHidden = false
                alertView.btnDismiss.isHidden = true
                alertView.btnCancel.isUserInteractionEnabled = true
                alertView.btnOk.isUserInteractionEnabled = true
                alertView.btnDismiss.isUserInteractionEnabled = false
            }
            alertView.lblAlartMessage.text = message ?? ""
            alertView.animate()
            if let cancel = cancelTitle, cancel.count > 0 { return}
            alertView.btnCancel.removeFromSuperview()
        }
    }
    
    //MARK:- Animate
    func animate() {
        self.dialogView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            self.dialogView.transform = .identity
        }, completion: nil)
    }
    
    func remove() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            self.dialogView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            self.dialogView.alpha = 0
            self.alertBgView.alpha = 0
        }, completion: { isFinished in
            self.removeFromSuperview()
        })
    }
    
    //MARK:- Button Action
    @IBAction func btnActionDismiss(_ sender: UIButton) {
        remove()
        callBack?(sender.tag)
    }
    
    @IBAction func btnActionCancel(_ sender: UIButton) {
        remove()
        callBack?(sender.tag)
    }
    
    @IBAction func btnActionOk(_ sender: UIButton) {
        remove()
        callBack?(sender.tag)
    }
}

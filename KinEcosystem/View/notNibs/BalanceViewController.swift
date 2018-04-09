//
//  BalanceViewController.swift
//  KinEcosystem
//
//  Created by Elazar Yifrach on 04/03/2018.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import UIKit
import KinSDK
import KinUtil
import StellarKit
import CoreDataStack

class BalanceViewController: UIViewController {

    var core: Core!
    @IBOutlet weak var balanceAmount: UILabel!
    @IBOutlet weak var balance: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var rightAmountConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightArrowImage: UIImageView!
    
    fileprivate var selected = false
    fileprivate let bag = LinkBag()
    fileprivate var watchedOrderStatus: OrderStatus?
    
    fileprivate var entityWatcher: EntityWatcher<Order>?
    fileprivate var currentOrderId: String?
    var watchedOrderId: String? {
        get {
            return currentOrderId
        }
        set {
            guard newValue != currentOrderId else { return }
            currentOrderId = newValue
            entityWatcher = nil
            guard let orderId = currentOrderId else { return }
            setupOrderWatcherFor(orderId)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        core.blockchain.currentBalance.on(queue: .main, next: { [weak self] balanceState in
            guard let this = self else { return }            
            if case let .pendind(value) = balanceState {
                this.balanceAmount.attributedText = "\(value)".attributed(24.0,
                                                                                           weight: .regular,
                                                                                           color: .kinBlueGreyTwo)
            }
            if case let .errored(value) = balanceState {
                this.balanceAmount.attributedText = "\(value)".attributed(24.0,
                                                                                           weight: .regular,
                                                                                           color: .kinCoralPink)
            }
            if case let .verified(value) = balanceState {
                this.balanceAmount.attributedText = "\(value)".attributed(24.0,
                                                                                           weight: .regular,
                                                                                           color: .kinDeepSkyBlue)
            }

        }).add(to: bag)
        _ = core.blockchain.balance()
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "WatchOrderNotification"), object: nil, queue: .main) { [weak self] note in
            guard let orderId = note.object as? String else {
                
                guard let status = self?.watchedOrderStatus, status != .pending else {
                    return
                }
                guard let label = self?.subtitle else { return }
                UIView.transition(with: label, duration: 0.3, options: .transitionCrossDissolve, animations: {
                    label.attributedText = "Welcome to Kin Marketplace".attributed(14.0, weight: .regular, color: .kinBlueGreyTwo)
                }, completion: nil)
                
                self?.watchedOrderId = nil
                self?.watchedOrderStatus = nil
                return
            }
            self?.watchedOrderId = orderId
        }
    }
    
    
    
    func setSelected(_ selected: Bool, animated: Bool) {
        guard self.selected != selected else { return }
        
        self.selected = selected
        
        self.rightAmountConstraint.constant = selected ? 0.0 : 20.0
        let block = {
            self.rightArrowImage.alpha = selected ? 0.0 : 1.0
            self.view.layoutIfNeeded()
        }
        
        guard animated else {
            block()
            return
        }
        
        UIView.animate(withDuration: TimeInterval(UINavigationControllerHideShowBarDuration)) {
            block()
        }
    }
    
    func setupOrderWatcherFor(_ orderId: String) {
        if let watcher = try? EntityWatcher<Order>(predicate: NSPredicate(with: ["id":orderId]), sortDescriptors: [], context: core.data.stack.viewContext) {
            entityWatcher = watcher
            entityWatcher?.on(EntityWatcher<Order>.Event.change, handler: { [weak self] change in
                guard let order = change?.entity else {
                    logWarn("Entity watcher inconsistent")
                    return
                }
                let status = order.orderStatus
                let spend = order.offerType == .spend
                let amount = order.amount
                self?.watchedOrderStatus = order.orderStatus
                DispatchQueue.main.async {
                    guard let label = self?.subtitle else { return }
                    switch status {
                    case .completed:
                        UIView.transition(with: label, duration: 0.3, options: .transitionCrossDissolve, animations: {
                            label.attributedText = (spend ? "Great, your code is ready" : "Done! \(amount) Kin earned").attributed(14.0, weight: .regular, color: .kinDeepSkyBlue)
                        }, completion: nil)
                        
                    case .pending:
                        UIView.transition(with: label, duration: 0.3, options: .transitionCrossDissolve, animations: {
                            label.attributedText = (spend ? "Thanks! We're generating your code..." : "Thanks! \(amount) Kin are on the way").attributed(14.0, weight: .regular, color: .kinBlueGreyTwo)
                        }, completion: nil)
                    case .failed:
                        UIView.transition(with: label, duration: 0.3, options: .transitionCrossDissolve, animations: {
                            label.attributedText = "Oops - something went wrong".attributed(14.0, weight: .regular, color: .kinCoralPink)
                        }, completion: nil)
                    case .delayed:
                        UIView.transition(with: label, duration: 0.3, options: .transitionCrossDissolve, animations: {
                            label.attributedText = "Sorry - this may take some time".attributed(14.0, weight: .regular, color: .kinMango)
                        }, completion: nil)
                    }
                    
                }
            })
        }
    }
}

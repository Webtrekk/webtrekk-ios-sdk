import Foundation

class AppinstallGoal{
    
    private static let appinstallGoal = "appinstallGoal"
    private static let appinstallGoalProcessed = "appinstallGoalProcessed"
    private let sharedDefaults = UserDefaults.standardDefaults.child(namespace: "webtrekk")

    
    func setupAppinstallGoal(){
        guard !isAppinstallGoalProcessed() else {
            return
        }
        
        self.sharedDefaults.set(key: AppinstallGoal.appinstallGoal, to: true)
    }
    
    func checkAppinstallGoal() -> Bool{
        let goal = self.sharedDefaults.boolForKey(AppinstallGoal.appinstallGoal)
        return goal ?? false
    }
    
    func fininshAppinstallGoal(){
        if self.checkAppinstallGoal() {
            self.sharedDefaults.remove(key: AppinstallGoal.appinstallGoal)
            appinstallGoalProcessFinished()
        }
    }
    
    private func appinstallGoalProcessFinished(){
        self.sharedDefaults.set(key: AppinstallGoal.appinstallGoalProcessed, to: true)
    }

    private func isAppinstallGoalProcessed() -> Bool{
        return self.sharedDefaults.boolForKey(AppinstallGoal.appinstallGoalProcessed) ?? false
    }
}

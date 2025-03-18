//
//  SigninView.swift
//  swiftUIChatter
//
//  Created by BlessedAmulya Parmar on 2/26/25.
//


import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct SigninView: View {
    @Binding var isPresented: Bool
    private let signinClient = GIDSignIn.sharedInstance
    
    var body: some View {
        if let rootVC = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.rootViewController {
            GoogleSignInButton {
                signinClient.signIn(withPresenting: rootVC){ result, error in
                    if error != nil {
                        print("signIn: \(error!.localizedDescription)")
                    } else {
                        backendSignin(result?.user.idToken?.tokenString)
                    }
                }
            }
            .frame(width:100, height:50, alignment: Alignment.center)
                        .onAppear {
                if let user = signinClient.currentUser {
                    backendSignin(user.idToken?.tokenString)
                } else {
                    signinClient.restorePreviousSignIn { user, error in
                        guard let _ = error else {
                            backendSignin(user?.idToken?.tokenString)
                            return
                        } // else do nothing, let body show GoogleSignInButton
                    }
                }
            }
        }
    }
    
    func backendSignin(_ token: String?) {
        Task {
            if let _ = await SubmissionStore.shared.addUser(token) {
                await ChatterID.shared.save()
            }
            isPresented.toggle()
        }
    }
}

import SwiftUI

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    
    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()
            
            VStack {
                ScrollView {
                    ForEach(vm.messages) { msg in
                        HStack {
                            if msg.isUser { Spacer() }
                            Text(msg.text)
                                .padding()
                                .background(msg.isUser ? Color.blue : Color.gray.opacity(0.3))
                                .foregroundColor(msg.isUser ? .white : .black)
                                .cornerRadius(12)
                            if !msg.isUser { Spacer() }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
                
                HStack {
                    TextField("Type a message", text: $vm.inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Send") {
                        vm.sendMessage()
                    }
                }
                .padding()
            }
        }
    }
}

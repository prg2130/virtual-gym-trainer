import SwiftUI

struct FormTip: Identifiable {
    let id = UUID()
    let message: String
    let isGood: Bool
}

struct PushUpTrainingView: View {
    @Binding var isPresented: Bool
    @State private var elapsedTime = 0
    @State private var timer: Timer?
    @State private var tips: [FormTip] = [
        FormTip(message: "✓ Shoulders aligned", isGood: true),
        FormTip(message: "✓ Body is straight", isGood: true),
        FormTip(message: "✓ Good depth", isGood: true)
    ]

    var body: some View {
        ZStack {
            // Camera background
            CameraViewRepresentable()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Push-up Training")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Text("\(elapsedTime)s")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color.black.opacity(0.3))

                Spacer()

                VStack(spacing: 16) {
                    Text("Live Form Analysis")
                        .font(.headline)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(tips) { tip in
                            TipRow(icon: tip.isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                                  text: tip.message,
                                  color: tip.isGood ? .green : .orange)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
                .background(Color.black.opacity(0.2))

                HStack(spacing: 12) {
                    Button(action: { isPresented = false }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Done")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .foregroundColor(.white)
            Spacer()
        }
        .font(.subheadline)
    }
}

#Preview {
    PushUpTrainingView(isPresented: .constant(true))
}

//
//  ContentView.swift
//  VirtualGymTrainer
//
//  Created by Palash Gajbhiye on 11/9/26.
//

import SwiftUI

struct Machine: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let targetMuscles: [String]
}

struct ContentView: View {
    @State private var selectedMachine: String?
    @State private var showAlert = false
    @State private var showTraining = false

    let machines = [
        Machine(id: "1", name: "Lat Pulldown", description: "Back and biceps", targetMuscles: ["Latissimus Dorsi", "Biceps"]),
        Machine(id: "2", name: "Chest Press", description: "Chest, shoulders, triceps", targetMuscles: ["Chest", "Shoulders"]),
        Machine(id: "3", name: "Leg Press", description: "Quads, hamstrings, glutes", targetMuscles: ["Quadriceps", "Hamstrings"]),
        Machine(id: "4", name: "Push-up", description: "Chest, shoulders, triceps, core", targetMuscles: ["Chest", "Shoulders", "Triceps"])
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Virtual Gym Trainer")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                Text("Select a machine to start training")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(machines) { machine in
                            Button(action: {
                                selectedMachine = machine.name
                                showAlert = true
                            }) {
                                MachineCard(machine: machine)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.vertical)
            .alert("Start Training?", isPresented: $showAlert) {
                Button("Start") {
                    if selectedMachine == "Push-up" {
                        showTraining = true
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Ready to train \(selectedMachine ?? "")?")
            }
            .sheet(isPresented: $showTraining) {
                PushUpTrainingView(isPresented: $showTraining)
            }
        }
    }
}

struct MachineCard: View {
    let machine: Machine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(machine.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(machine.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
            }

            HStack(spacing: 8) {
                ForEach(machine.targetMuscles.prefix(2), id: \.self) { muscle in
                    Text(muscle)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
}

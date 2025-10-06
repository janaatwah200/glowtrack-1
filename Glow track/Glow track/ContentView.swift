import SwiftUI

// MARK: - 1. CONFIGURATION & MODELS

/// Custom color defined in the friend's design for pink accents.
let accentPink = Color(red: 0.8, green: 0.4, blue: 0.5)

enum ProductCategory: String, CaseIterable {
    case eyes = "Eyes"
    case lips = "Lips"
    case face = "Face"
    
    var iconName: String {
        switch self {
        case .eyes: return "eyebrow"
        case .lips: return "mouth.fill"
        case .face: return "face.smiling"
        }
    }
}

struct Product: Identifiable, Equatable { // Added Equatable for clean state management
    let id = UUID()
    var name: String
    var category: ProductCategory
    
    var dateAdded: Date = Date()
    var paoMonths: Int?
    var expiryDate: Date?
    
    // Helper to format the expiry date (FIX)
    var formattedExpiryDate: String? {
        guard let expiry = expiryDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: expiry)
    }
    
    // Helper to determine the single critical expiration date (PAO or Expiry, whichever is sooner)
    var finalExpirationDate: Date? {
        var expirationCheckDate: Date? = nil
        
        // Check 1: Explicit Expiry Date
        if let expiry = expiryDate {
            expirationCheckDate = expiry
        }
        
        // Check 2: PAO Limit Date (starts from dateAdded)
        if let pao = paoMonths {
            let paoLimitDate = Calendar.current.date(byAdding: .month, value: pao, to: dateAdded)
            if paoLimitDate != nil && (expirationCheckDate == nil || paoLimitDate! < expirationCheckDate!) {
                expirationCheckDate = paoLimitDate
            }
        }
        return expirationCheckDate
    }
    
    // Status Check (Kept from friend's original complex logic)
    var isExpired: Bool {
        if let finalDate = finalExpirationDate, finalDate < Date() {
            return true
        }
        return false
    }
    
    var statusColor: Color {
        if isExpired {
            return .red
        }
        
        if let checkDate = finalExpirationDate {
            let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: checkDate).day ?? 0
            
            if daysRemaining <= 90 { // 3 أشهر أو أقل
                return .yellow
            }
        }
        
        return .green
    }
    
    var trackingMethodDescription: String {
        if paoMonths != nil && expiryDate != nil {
            return "Tracking by PAO (\(paoMonths!) months) & Expiry Date"
        } else if let pao = paoMonths {
            return "Tracking by PAO (\(pao) months)"
        } else if expiryDate != nil {
            return "Tracking by Fixed Expiry Date"
        } else {
            return "No Tracking Method Set"
        }
    }
}

class ProductManager: ObservableObject {
    @Published var products: [Product] = []
    
    func addProduct(product: Product) {
        products.append(product)
        products.sort { $0.dateAdded > $1.dateAdded }
    }
    
    // NEW: Function to update an existing product
    func updateProduct(product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
            // Re-sort after update
            products.sort { $0.dateAdded > $1.dateAdded }
        }
    }
    
    // NEW: Function to delete a product
    func deleteProduct(product: Product) {
        products.removeAll { $0.id == product.id }
    }
}

// MARK: - 2. TRACKING LOGIC (Adapted from your original code)

/// Handles the live countdown calculation and status for a single Product.
class CountdownLogic: ObservableObject {
    @Published var product: Product
    
    @Published var months: Int = 0
    @Published var weeks: Int = 0
    @Published var days: Int = 0
    @Published var isExpired: Bool = false
    
    private var timer: Timer?
    
    init(product: Product) {
        self.product = product
        self.isExpired = product.isExpired // Initial check
        if !self.isExpired {
            startTimer()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func startTimer() {
        // Update every 10 seconds (or 1.0 second if needed, but 10s is cleaner for battery)
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.updateTime()
        }
        self.updateTime() // Initial update
    }
    
    private func updateTime() {
        guard let expiry = product.finalExpirationDate, expiry > Date() else {
            isExpired = true
            timer?.invalidate()
            months = 0; weeks = 0; days = 0
            return
        }
        
        let now = Date()
        
        let components = Calendar.current.dateComponents(
            [.month, .weekOfMonth, .day],
            from: now,
            to: expiry
        )
        
        // This calculation is approximate but gives a good high-level overview
        self.months = components.month ?? 0
        // Use remaining days after months are accounted for to calculate weeks/days
        let remainingDaysInPeriod = Calendar.current.dateComponents([.day], from: now, to: expiry).day ?? 0
        let daysAfterMonths = remainingDaysInPeriod - (self.months * 30) // Approximation
        
        self.weeks = max(0, daysAfterMonths / 7)
        self.days = max(0, daysAfterMonths % 7)
    }
    
    // Uses the main Product status logic for consistency
    var statusText: String {
        if product.isExpired {
            return "EXPIRED"
        }
        if product.statusColor == .yellow {
            return "EXPIRY SOON"
        }
        return "FRESH"
    }
}

// MARK: - 3. COMPONENTS (Styled to match the Home View)

/// Reusable view for displaying a single countdown unit (Redesigned)
struct CountdownUnitView: View {
    let value: Int
    let label: String
    let color: Color // Pass the main status color
    
    var body: some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundColor(color)
                .frame(width: 70, height: 70)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                )
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CategorySelectionView: View {
    let category: ProductCategory
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isSelected ? accentPink.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    
                Image(systemName: category.iconName)
                    .font(.largeTitle)
                    .foregroundColor(isSelected ? accentPink : .gray)
            }
            Text(category.rawValue)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

struct DateTypeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(title) {
            action()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 15)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isSelected ? accentPink : Color(.systemGray4), lineWidth: 2)
                .fill(isSelected ? accentPink.opacity(0.1) : Color.white)
        )
        .foregroundColor(isSelected ? accentPink : .gray)
        .font(.subheadline)
    }
}

struct AppleSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            // العدسة
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            // خانة النص
            TextField("Search", text: $text)
                .foregroundColor(.primary)
                .disableAutocorrection(true)
            
            Spacer()
            
            // إذا فاضي = ميكروفون
            if text.isEmpty {
               
                  
            } else {
                // إذا فيه نص = زر مسح
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.4))
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

struct ProductCellView: View {
    let product: Product
    let isEditing: Bool
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().fill(Color.white)
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.black.opacity(0.1), radius: 5)
                Image(systemName: product.category.iconName)
                    .font(.largeTitle)
                    .foregroundColor(accentPink)
                if isEditing {
                    Circle().fill(Color.black.opacity(0.35))
                        .frame(width: 70, height: 70)
                    Text("Edit").font(.caption.bold()).foregroundColor(.white)
                }
            }
            .overlay(alignment: .topTrailing) {
                Circle().fill(product.statusColor).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: 5, y: -5)
            }
            .frame(width: 80, height: 80)
            
            Text(product.name).font(.caption).lineLimit(1)
                .multilineTextAlignment(.center).foregroundColor(.secondary)
        }.padding(.bottom, 10)
    }
}

struct ShelfView: View {
    let products: [Product]
    let itemsPerShelf = 3 // عدد المنتجات في كل رف
    
    let isEditing: Bool // NEW: Passed from HomeView
    
    // Closure to handle item taps, passing the selected product
    let onProductTap: (Product) -> Void
    
    private let gridLayout = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: gridLayout, spacing: 10) {
                ForEach(products) { product in
                    ProductCellView(product: product, isEditing: isEditing) // Pass isEditing
                        .onTapGesture {
                            onProductTap(product)
                        }
                }
                ForEach(0..<(itemsPerShelf - products.count), id: \.self) { _ in
                    Spacer() // خلية فارغة
                        .frame(width: 70, height: 90)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(height: 6)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 16)
        }
        .frame(height: 150)
        .padding(.bottom, 30) // مسافة بين الرفوف
    }
}

// MARK: - 4. PICKER VIEWS (Kept from friend's code)

struct PAOPickerView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var selectedPAO: String
    @State private var workingPAO: String
    
    let paoOptions = ["2 Months","6 Months", "12 Months", "18 Months", "24 Months", "36 Months"]
    
    init(selectedPAO: Binding<String>) {
        self._selectedPAO = selectedPAO
        self._workingPAO = State(initialValue: selectedPAO.wrappedValue)
    }

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                ForEach(paoOptions, id: \.self) { option in
                    Text(option)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(workingPAO == option ? accentPink.opacity(0.1) : Color.white)
                        .overlay(
                            workingPAO == option ? Image(systemName: "checkmark").padding(.leading) : nil,
                            alignment: .leading
                        )
                        .onTapGesture { workingPAO = option }
                    Divider().opacity(option == paoOptions.last ? 0 : 1)
                }
            }
            .background(Color.white)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding()
            
            Button("Save") {
                selectedPAO = workingPAO
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(accentPink)
            .padding(.bottom, 20)
            .background(accentPink) // إضافة هذه السطر
            .foregroundColor(.white) // تغيير لون النص إلى الأبيض
        }
    }
}

struct ExpiryDatePickerView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var selectedDate: Date
    @State private var workingDate: Date
    
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._workingDate = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        VStack {
            Text("Select Expiry Date")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
                .foregroundColor(.primary)
            
            DatePicker("", selection: $workingDate, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 200)
                .clipped()
            
            Button("Save") {
                selectedDate = workingDate
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(accentPink)
            .padding(.bottom, 20)
            .background(accentPink) // إضافة هذه السطر
            .foregroundColor(.white) // تغيير لون النص إلى الأبيض
        }
    }
}

// MARK: - 5. APPLICATION FLOW VIEWS

// 5.1. Tracking Page (Redesigned to match the friend's style)
struct TrackingSheetView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var logic: CountdownLogic
    
    init(product: Product) {
        _logic = StateObject(wrappedValue: CountdownLogic(product: product))
    }
    
    var body: some View {
        VStack(spacing: 25) {
            
            // --- Close Button ---
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            }
            .padding([.horizontal, .top])
            
            // --- Product Icon & Name (Using SF Symbol instead of Emoji) ---
            Image(systemName: logic.product.category.iconName)
                .font(.system(size: 80))
                .foregroundColor(accentPink)
                .padding(.bottom, 10)
                
            Text(logic.product.name)
                .font(.largeTitle.bold())
                .foregroundColor(.primary)

            // --- Status Bubble ---
            Text(logic.statusText)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 6)
                .background(logic.product.statusColor)
                .clipShape(Capsule())
            
            // --- Remaining Days Label ---
            Text("Time remaining until expiry:")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top, 10)
            
            // --- The Countdown Counters (Styled to match the light theme) ---
            HStack(spacing: 15) {
                CountdownUnitView(value: logic.days, label: "Days", color: logic.product.statusColor)
                CountdownUnitView(value: logic.weeks, label: "Weeks", color: logic.product.statusColor)
                CountdownUnitView(value: logic.months, label: "Months", color: logic.product.statusColor)
            }
            .padding(.horizontal, 20)
            
            // --- Tracking Detail (Updated to include date) ---
            VStack(spacing: 5) {
                Text(logic.product.trackingMethodDescription)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Show the date only if an explicit expiry date exists
                if logic.product.expiryDate != nil,
                   let formattedDate = logic.product.formattedExpiryDate {
                    
                    Text(formattedDate)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(red: 0.3, green: 0.1, blue: 0.2))
                }
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Light, cohesive background
        .background(Color(red: 0.95, green: 0.92, blue: 0.93))
    }
}


struct SplashScreenView: View {
    @State private var isActive = false
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.92, blue: 0.93) // Light Beige/Pink background
                .edgesIgnoringSafeArea(.all)
            
            if isActive {
                // Navigation to the main app interface
                HomeView()
                    .environmentObject(ProductManager())
            } else {
                VStack {
                    // Placeholder icon for the splash screen
                    Image("ss")
                        .resizable()
                        .scaledToFit()
                        .frame(width:250)
                        .shadow(radius: 10)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}

struct HomeView: View {
    @State private var showingAddProduct = false
    @EnvironmentObject var productManager: ProductManager
    @State private var searchText = ""
    
    // State to manage the tracking sheet presentation
    @State private var selectedProductForTracking: Product? = nil
    
    // NEW: State for editing mode and sheet presentation
    @State private var isEditingMode: Bool = false
    @State private var selectedProductForEditing: Product? = nil
    
    private var shelfGroups: [[Product]] {
        let filteredProducts = productManager.products.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return filteredProducts.chunked(into: 3)
    }
    
    private func numberOfShelvesToDisplay() -> Int {
        if searchText.isEmpty {
            if productManager.products.isEmpty {
                return 3
            }
            return shelfGroups.count
        } else {
            return shelfGroups.count
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    gradient: Gradient(colors: [
                        accentPink.opacity(0.35),
                        Color.white
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Hello, Gorgeous!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.3, green: 0.1, blue: 0.2))
                        .padding(.top, 20)
                        .padding(.leading, 20)
                        
                    AppleSearchBar(text: $searchText)

                    ScrollView {
                        VStack(spacing: 0) {
                            if productManager.products.isEmpty && searchText.isEmpty {
                                // Empty state message
                                VStack(spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .font(.largeTitle)
                                        .foregroundColor(accentPink.opacity(0.8))
                                    
                                    Text("It's a clean slate! Tap '+' to get started.")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color(red: 0.3, green: 0.1, blue: 0.2))
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.white.opacity(0.8))
                                        .shadow(color: accentPink.opacity(0.2), radius: 5, x: 0, y: 3)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(accentPink.opacity(0.4), lineWidth: 1)
                                        )
                                )
                                .padding(.horizontal, 30)
                                .padding(.top, 50)
                                
                                ForEach(0..<3, id: \.self) { _ in
                                    ShelfView(products: [], isEditing: isEditingMode) { _ in }
                                }
                            } else if shelfGroups.isEmpty && !searchText.isEmpty {
                                Text("No results found for '\(searchText)'")
                                    .foregroundColor(.gray)
                                    .padding(.top, 50)
                                
                            } else {
                                ForEach(shelfGroups.indices, id: \.self) { index in
                                    ShelfView(products: shelfGroups[index], isEditing: isEditingMode) { product in
                                        if isEditingMode {
                                            selectedProductForEditing = product
                                        } else {
                                            selectedProductForTracking = product
                                        }
                                    }
                                }
                                
                                if numberOfShelvesToDisplay() < 3 {
                                    ForEach(numberOfShelvesToDisplay()..<3, id: \.self) { _ in
                                        ShelfView(products: [], isEditing: isEditingMode) { _ in }
                                    }
                                }
                            }
                        }
                        .padding(.top, 40)
                        
                        Spacer().frame(height: 100)
                    }
                }
                
                if !isEditingMode {
                    Button(action: { showingAddProduct = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(accentPink)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.bottom, 20)
                    .alignmentGuide(.bottom) { $0[.bottom] }
                }
            }
            // NEW: Edit Button (Always available at the top right)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !productManager.products.isEmpty {
                        Button {
                            withAnimation(.spring()) {
                                isEditingMode.toggle()
                                selectedProductForTracking = nil
                            }
                        } label: {
                            Text(isEditingMode ? "Done" : "Edit")
                                .foregroundColor(accentPink)
                                .font(.headline)
                        }
                    }
                }
            }
            // Sheet for Adding a new Product
            .sheet(isPresented: $showingAddProduct) {
                ProductDetailView(editingProduct: nil)
                    .environmentObject(productManager)
            }
            // NEW: Sheet for Editing an existing Product
            .sheet(item: $selectedProductForEditing) { product in
                ProductDetailView(editingProduct: product)
                    .environmentObject(productManager)
                    .onDisappear {
                        selectedProductForEditing = nil
                        isEditingMode = false
                    }
            }
            // Sheet for Tracking
            .sheet(item: $selectedProductForTracking) { product in
                TrackingSheetView(product: product)
            }
        }
    }
}

/// Enum يحدد خيارات التاريخ
enum DateOption: String, CaseIterable {
    case pao = "PAO"
    case expiry = "Expiry Date"
}

/// Segmented Control مخصص بنفس ستايل أبل لكن بلون accentPink
struct SegmentedDateSelectionView: View {
    @Binding var selectedDateType: DateOption
    var onSelection: (DateOption) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(DateOption.allCases, id: \.self) { option in
                Button(action: {
                    withAnimation(.spring()) {
                        selectedDateType = option
                        onSelection(option)
                    }
                }) {
                    Text(option.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(selectedDateType == option ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if selectedDateType == option {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(accentPink)
                                }
                            }
                        )
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.vertical, 5)
    }
}

struct ProductDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var productManager: ProductManager
    
    // States initialized from the product (if editing) or defaults (if adding)
    @State private var productName: String
    @State private var selectedCategory: ProductCategory
    @State private var selectedDateType: DateOption = .pao   // ✅ Enum بدل String
    
    @State private var selectedPAOString: String
    @State private var selectedExpiryDate: Date
    
    @State private var showPAOPicker: Bool = false
    @State private var showExpiryDatePicker: Bool = false
    
    // NEW: Optional product passed for editing
    let editingProduct: Product?
    
    // Initializer
    init(editingProduct: Product? = nil) {
        self.editingProduct = editingProduct
        
        if let product = editingProduct {
            _productName = State(initialValue: product.name)
            _selectedCategory = State(initialValue: product.category)
            
            // حدد النوع الافتراضي حسب البيانات المخزنة
            if product.paoMonths != nil {
                _selectedDateType = State(initialValue: .pao)
            } else if product.expiryDate != nil {
                _selectedDateType = State(initialValue: .expiry)
            }
            
            _selectedPAOString = State(initialValue: product.paoMonths != nil ? "\(product.paoMonths!) Months" : "12 Months")
            _selectedExpiryDate = State(initialValue: product.expiryDate ?? Date().addingTimeInterval(365 * 24 * 60 * 60))
            
        } else {
            _productName = State(initialValue: "")
            _selectedCategory = State(initialValue: .lips)
            _selectedDateType = State(initialValue: .pao)
            _selectedPAOString = State(initialValue: "12 Months")
            _selectedExpiryDate = State(initialValue: Date().addingTimeInterval(365 * 24 * 60 * 60))
        }
    }
    
    // Save/Update Product
    func saveOrUpdateProduct() {
        let paoMonths: Int?
        let expiry: Date?
        
        if selectedDateType == .pao {
            let paoComponents = selectedPAOString.components(separatedBy: " ")
            paoMonths = Int(paoComponents.first ?? "0")
            expiry = nil
        } else {
            paoMonths = nil
            expiry = selectedExpiryDate
        }
        
        if var product = editingProduct {
            // تحديث
            product.name = productName.isEmpty ? "\(selectedCategory.rawValue) Item" : productName
            product.category = selectedCategory
            product.paoMonths = paoMonths
            product.expiryDate = expiry
            productManager.updateProduct(product: product)
        } else {
            // إضافة جديدة
            let newProduct = Product(
                name: productName.isEmpty ? "\(selectedCategory.rawValue) Item" : productName,
                category: selectedCategory,
                dateAdded: Date(),
                paoMonths: paoMonths,
                expiryDate: expiry
            )
            productManager.addProduct(product: newProduct)
        }
        dismiss()
    }
    
    // Delete
    func deleteProduct() {
        guard let product = editingProduct else { return }
        productManager.deleteProduct(product: product)
        dismiss()
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.92, blue: 0.93)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                mainContentContainer
            }
        }
        .sheet(isPresented: $showPAOPicker) {
            PAOPickerView(selectedPAO: $selectedPAOString)
                .presentationDetents([.fraction(0.5)])
        }
        .sheet(isPresented: $showExpiryDatePicker) {
            ExpiryDatePickerView(selectedDate: $selectedExpiryDate)
                .presentationDetents([.fraction(0.5)])
        }
    }
    
    var mainContentContainer: some View {
        VStack(alignment: .leading, spacing: 25) {
            
            // أزرار أعلى الشاشة
            HStack {
                Spacer()
                if editingProduct != nil {
                    Button(action: deleteProduct) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                            .padding(.trailing, 10)
                    }
                }
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            
            // اختيار النوع
            VStack(alignment: .leading) {
                Text("Choose the type of your product")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack {
                    ForEach(ProductCategory.allCases, id: \.self) { category in
                        CategorySelectionView(
                            category: category,
                            isSelected: selectedCategory == category
                        )
                        .onTapGesture { selectedCategory = category }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // اسم المنتج
            VStack(alignment: .leading) {
                Text("Product name")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("MAC Lipstick - Mehr", text: $productName)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            // شريحة الاختيار الجديدة
            VStack(alignment: .leading, spacing: 10) {
                Text("Select the expiration type:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                SegmentedDateSelectionView(selectedDateType: $selectedDateType) { option in
                    selectedDateType = option
                    if option == .pao {
                        showPAOPicker = true
                        showExpiryDatePicker = false
                    } else {
                        showExpiryDatePicker = true
                        showPAOPicker = false
                    }
                }
                
                // النص أسفل الشريحة
                Text(selectedDateType == .pao ?
                     "PAO: \(selectedPAOString)" :
                     "Expiry Date: \(selectedExpiryDate.formatted(date: .numeric, time: .omitted))")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 5)
            }
            
            Spacer()
            
            Button(editingProduct != nil ? "Update" : "Save") {
                saveOrUpdateProduct()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(accentPink.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(15)
            
        }
        .padding()
        .background(Color.white)
        .cornerRadius(30)
        .padding(.horizontal)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - 6. ROOT VIEW & EXTENSIONS

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

struct ContentView: View {
    var body: some View {
        SplashScreenView()
    }
}

#Preview {
    ContentView()
}

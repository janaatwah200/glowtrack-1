import SwiftUI

// MARK: - 1. CONSTANTS AND DATA MODELS
let accentPink = Color(red: 0.8, green: 0.4, blue: 0.5)

enum ProductCategory: String, CaseIterable, Codable {
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

struct Product: Identifiable, Equatable, Codable {
    let id: UUID = UUID()
    var name: String
    var category: ProductCategory
    
    var dateAdded: Date = Date()
    var paoMonths: Int?
    var expiryDate: Date?
    
    var formattedExpiryDate: String? {
        guard let expiry = expiryDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: expiry)
    }
    
    var finalExpirationDate: Date? {
        var expirationCheckDate: Date? = nil
        
        if let expiry = expiryDate {
            expirationCheckDate = expiry
        }
        
        if let pao = paoMonths {
            let paoLimitDate = Calendar.current.date(byAdding: .month, value: pao, to: dateAdded)
            if paoLimitDate != nil && (expirationCheckDate == nil || paoLimitDate! < expirationCheckDate!) {
                expirationCheckDate = paoLimitDate
            }
        }
        return expirationCheckDate
    }
    
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
            let daysRemaining = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: checkDate)).day ?? 0
            
            if daysRemaining <= 90 {
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
    @Published var products: [Product] = [] {
        didSet {
            saveProducts()
        }
    }
    
    private let productsKey = "ProductData"

    init() {
        loadProducts()
    }

    func loadProducts() {
        if let savedData = UserDefaults.standard.data(forKey: productsKey) {
            if let decodedProducts = try? JSONDecoder().decode([Product].self, from: savedData) {
                self.products = decodedProducts.sorted { $0.dateAdded > $1.dateAdded }
                return
            }
        }
        self.products = []
    }
    
    func saveProducts() {
        if let encodedData = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(encodedData, forKey: productsKey)
        }
    }
    
    func addProduct(product: Product) {
        products.append(product)
        products.sort { $0.dateAdded > $1.dateAdded }
    }
    
    func updateProduct(product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
            products.sort { $0.dateAdded > $1.dateAdded }
        }
    }
    
    func deleteProduct(product: Product) {
        products.removeAll { $0.id == product.id }
    }
}

class CountdownLogic: ObservableObject {
    @Published var product: Product
    
    @Published var months: Int = 0
    @Published var weeks: Int = 0
    @Published var days: Int = 0
    @Published var isExpired: Bool = false
    
    private var timer: Timer?
    
    init(product: Product) {
        _product = Published(initialValue: product)
        _isExpired = Published(initialValue: product.isExpired)
        if !product.isExpired {
            startTimer()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.updateTime()
        }
        self.updateTime()
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
            [.month, .day],
            from: now,
            to: expiry
        )
        
        self.months = components.month ?? 0
        
        if let futureDate = Calendar.current.date(byAdding: .month, value: self.months, to: now) {
            let remainingDaysInPeriod = Calendar.current.dateComponents([.day], from: futureDate, to: expiry).day ?? 0
            
            self.weeks = max(0, remainingDaysInPeriod / 7)
            self.days = max(0, remainingDaysInPeriod % 7)
        } else {
            let totalDays = Calendar.current.dateComponents([.day], from: now, to: expiry).day ?? 0
            self.weeks = max(0, totalDays / 7)
            self.days = max(0, totalDays % 7)
        }
    }
    
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

// MARK: - 2. COMPONENTS

struct CountdownUnitView: View {
    let value: Int
    let label: String
    let color: Color
    
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

struct AppleSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search", text: $text)
                .foregroundColor(.primary)
                .disableAutocorrection(true)
            
            Spacer()
            
            if text.isEmpty {
                Button {
                    print("Mic tapped")
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.gray)
                }
            } else {
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
    let itemsPerShelf = 3
    let isEditing: Bool
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
                    ProductCellView(product: product, isEditing: isEditing)
                        .onTapGesture {
                            onProductTap(product)
                        }
                }
                ForEach(0..<(itemsPerShelf - products.count), id: \.self) { _ in
                    Spacer()
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
        .padding(.bottom, 30)
    }
}

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
        }
    }
}

struct ExpiryDatePickerView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var selectedDate: Date
    @State private var workingDate: Date
    
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        let safeDate = selectedDate.wrappedValue < Date() ? Date().addingTimeInterval(365 * 24 * 60 * 60) : selectedDate.wrappedValue
        self._workingDate = State(initialValue: safeDate)
    }

    var body: some View {
        VStack {
            Text("Select Expiry Date")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
                .foregroundColor(.primary)
            
            DatePicker("", selection: $workingDate, in: Date()..., displayedComponents: .date)
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
        }
    }
}

enum DateOption: String, CaseIterable {
    case pao = "PAO"
    case expiry = "Expiry Date"
}

struct SegmentedDateSelectionView: View {
    @Binding var selectedDateType: DateOption
    var onSelection: (DateOption) -> Void
    
    @Namespace var namespace
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(DateOption.allCases, id: \.self) { option in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                                        .matchedGeometryEffect(id: "selection", in: namespace)
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

// MARK: - 3. APPLICATION VIEWS

struct TrackingSheetView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var logic: CountdownLogic
    
    init(product: Product) {
        _logic = StateObject(wrappedValue: CountdownLogic(product: product))
    }
    
    var body: some View {
        VStack(spacing: 25) {
            
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
            
            Image(systemName: logic.product.category.iconName)
                .font(.system(size: 80))
                .foregroundColor(accentPink)
                .padding(.bottom, 10)
                
            Text(logic.product.name)
                .font(.largeTitle.bold())
                .foregroundColor(.primary)

            Text(logic.statusText)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 6)
                .background(logic.product.statusColor)
                .clipShape(Capsule())
            
            Text("Time remaining until expiry:")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top, 10)
            
            HStack(spacing: 15) {
                CountdownUnitView(value: logic.months, label: "Months", color: logic.product.statusColor)
                CountdownUnitView(value: logic.weeks, label: "Weeks", color: logic.product.statusColor)
                CountdownUnitView(value: logic.days, label: "Days", color: logic.product.statusColor)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 5) {
                Text(logic.product.trackingMethodDescription)
                    .font(.caption)
                    .foregroundColor(.gray)
                
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
        .background(Color(red: 0.95, green: 0.92, blue: 0.93))
    }
}


struct ProductDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var productManager: ProductManager
    
    @State private var productName: String
    @State private var selectedCategory: ProductCategory
    @State private var selectedDateType: DateOption
    
    @State private var selectedPAOString: String
    @State private var selectedExpiryDate: Date
    
    @State private var showPAOPicker: Bool = false
    @State private var showExpiryDatePicker: Bool = false
    
    let editingProduct: Product?
    
    init(editingProduct: Product? = nil) {
        self.editingProduct = editingProduct
        
        let initialPAOString: String
        let initialDateType: DateOption
        
        if let product = editingProduct {
            initialPAOString = product.paoMonths != nil ? "\(product.paoMonths!) Months" : "12 Months"
            
            if product.paoMonths != nil {
                initialDateType = .pao
            } else if product.expiryDate != nil {
                initialDateType = .expiry
            } else {
                initialDateType = .pao
            }
            
            _productName = State(initialValue: product.name)
            _selectedCategory = State(initialValue: product.category)
            _selectedExpiryDate = State(initialValue: product.expiryDate ?? Date().addingTimeInterval(365 * 24 * 60 * 60))
            
        } else {
            initialPAOString = "12 Months"
            initialDateType = .pao
            
            _productName = State(initialValue: "")
            _selectedCategory = State(initialValue: .lips)
            _selectedExpiryDate = State(initialValue: Date().addingTimeInterval(365 * 24 * 60 * 60))
        }
        
        self._selectedDateType = State(initialValue: initialDateType)
        self._selectedPAOString = State(initialValue: initialPAOString)
    }
    
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
            product.name = productName.isEmpty ? "\(selectedCategory.rawValue) Item" : productName
            product.category = selectedCategory
            product.paoMonths = paoMonths
            product.expiryDate = expiry
            productManager.updateProduct(product: product)
        } else {
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
    
    func deleteProduct() {
        guard let product = editingProduct else { return }
        productManager.deleteProduct(product: product)
        dismiss()
    }
    
    var body: some View {
        VStack {
            mainContentContainer
        }
        .background(Color(red: 0.95, green: 0.92, blue: 0.93))
        .edgesIgnoringSafeArea(.all)
        // ❌ تم إزالة safeAreaInset من هنا
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
            
            VStack(alignment: .leading) {
                Text("Product name")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("MAC Lipstick - Mehr", text: $productName)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
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
                
                Text(selectedDateType == .pao ?
                     "PAO: \(selectedPAOString)" :
                     "Expiry Date: \(selectedExpiryDate.formatted(date: .numeric, time: .omitted))")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 5)
            }
            
            Spacer()
            
            // ✅ الزر المعدّل ليصبح أصغر ومرتفعاً قليلاً
            Button(editingProduct != nil ? "Update" : "Save") {
                saveOrUpdateProduct()
            }
            .frame(width: 200, height: 44) // تحديد عرض ثابت
            .background(accentPink)
            .foregroundColor(.white)
            .font(.headline)
            .cornerRadius(12)
            .shadow(color: accentPink.opacity(0.4), radius: 5, x: 0, y: 5)
            .padding(.vertical, 15) // هامش رأسي لرفعه قليلاً عن الحافة السفلية
            .frame(maxWidth: .infinity) // لجعل الزر يتوسط البطاقة البيضاء
        }
        .padding([.horizontal, .top], 20)
        .padding(.bottom, 10)
        .background(Color.white)
        .cornerRadius(30)
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity)
    }
}


struct SplashScreenView: View {
    @State private var isActive = false
    @EnvironmentObject var productManager: ProductManager
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.92, blue: 0.93)
                .edgesIgnoringSafeArea(.all)
            
            if isActive {
                HomeView()
            } else {
                VStack {
                    Image(systemName: "wand.and.stars")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150)
                        .foregroundColor(accentPink)
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
    
    @State private var selectedProductForTracking: Product? = nil
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
                    Text("Hello Gorgeous,")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.3, green: 0.1, blue: 0.2))
                        .padding(.top, 20)
                        .padding(.leading, 20)
                        
                    AppleSearchBar(text: $searchText)
                        
                    ScrollView {
                        VStack(spacing: 0) {
                            if productManager.products.isEmpty && searchText.isEmpty {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
            // ✅ تم تحديد ارتفاع الـ Sheet بـ 92% للسماح بظهور شريط البحث في الأعلى
            .sheet(isPresented: $showingAddProduct) {
                ProductDetailView(editingProduct: nil)
                    .environmentObject(productManager)
                    .presentationDetents([.fraction(0.82), .large])
            }
            // Sheet for Editing an existing Product
            .sheet(item: $selectedProductForEditing) { product in
                ProductDetailView(editingProduct: product)
                    .environmentObject(productManager)
                    .presentationDetents([.fraction(0.80), .large])
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

// MARK: - 4. EXTENSIONS AND ENTRY POINT

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

struct ContentView: View {
    @StateObject private var productManager = ProductManager()
    
    var body: some View {
        SplashScreenView()
            .environmentObject(productManager)
    }
}


#Preview {
    ContentView()
}

import Product from '../models/product';

const sampleProducts = [
    { title: "iPhone 15 Pro", description: "Latest Apple smartphone with A17 chip and titanium design", price: 999, photos: ["https://picsum.photos/400/400?random=1"] },
    { title: "Samsung Galaxy S24 Ultra", description: "Samsung flagship with AI-powered camera and S Pen", price: 1199, photos: ["https://picsum.photos/400/400?random=2"] },
    { title: "MacBook Pro M3", description: "Apple laptop with M3 Pro chip for professionals", price: 1999, photos: ["https://picsum.photos/400/400?random=3"] },
    { title: "AirPods Pro 2", description: "Wireless earbuds with adaptive noise cancellation", price: 249, photos: ["https://picsum.photos/400/400?random=4"] },
    { title: "iPad Air M2", description: "Lightweight tablet perfect for creativity and productivity", price: 599, photos: ["https://picsum.photos/400/400?random=5"] },
    { title: "Sony WH-1000XM5", description: "Premium over-ear headphones with best-in-class ANC", price: 349, photos: ["https://picsum.photos/400/400?random=6"] },
    { title: "Apple Watch Ultra 2", description: "Rugged smartwatch for outdoor adventures", price: 799, photos: ["https://picsum.photos/400/400?random=7"] },
    { title: "Nintendo Switch OLED", description: "Portable gaming console with vibrant OLED display", price: 349, photos: ["https://picsum.photos/400/400?random=8"] },
];

const seedDatabase = async () => {
    try {
        const count = await Product.countDocuments();
        if (count === 0) {
            await Product.insertMany(sampleProducts);
            console.log('Database seeded with sample products');
        }
    } catch (err) {
        console.log('Seed skipped:', err.message);
    }
};

export default seedDatabase;

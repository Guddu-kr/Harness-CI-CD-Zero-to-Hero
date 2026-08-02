import mongoose from 'mongoose';
import seedDatabase from './seed';

mongoose
  .connect(process.env.MONGO_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => {
    console.log('MongoDB: Connected');
    seedDatabase();
  })
  .catch((err) => console.log(err.message));

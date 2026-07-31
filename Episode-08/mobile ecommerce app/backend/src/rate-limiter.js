import RateLimit from 'express-rate-limit';
import Boom from 'boom';

// Use in-memory rate limiting (no Redis dependency for K8s deployment)
const limiter = new RateLimit({
  windowMs: 30 * 1000,
  max: 1000,
  handler: (req, res, next) => {
    next(Boom.tooManyRequests());
  },
});

export default limiter;

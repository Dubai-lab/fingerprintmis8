const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure the email transport using the default SMTP transport and a GMail account.
// For Gmail, enable "less secure apps" or use an app password.
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'eg8217178@gmail.com', // TODO: Replace with your email
    pass: 'blbugxtrbhzlwtfj',  // TODO: Replace with your email password or app password
  },
});

// Sends an email when a new user document is created in Firestore
exports.sendWelcomeEmail = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    const email = userData.email;
    const password = userData.password; // Assuming password is stored here (consider security implications)

    const mailOptions = {
      from: 'Your App <eg8217178@gmail.com>',
      to: email,
      subject: 'Welcome to Fingerprint MIS - Your Login Details',
      text: `Hello,

Your account has been successfully created.

Login details:
Email: ${email}
Password: ${password}

Please keep this information secure.

Thank you,
Fingerprint MIS Team`,
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log('Welcome email sent to:', email);
    } catch (error) {
      console.error('Error sending welcome email:', error);
    }
  });

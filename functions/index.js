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

exports.sendWelcomeEmail = functions.firestore
  .document('{collectionId}/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    const email = userData.email;
    const collectionId = context.params.collectionId;

    // Only send email for specific collections
    if (!['instructors', 'security', 'invigilators'].includes(collectionId)) {
      console.log('Document created in collection', collectionId, '- no email sent.');
      return null;
    }

    const defaultPassword = userData.defaultPassword ? 'DefaultPass123!' : null;

    let emailText = `Hello,

Your account has been successfully created.

Login details:
Email: ${email}
`;

    if (defaultPassword) {
      emailText += `
Your temporary password is: ${defaultPassword}

Please change your password within 24 hours after your first login.
`;
    } else {
      emailText += `
Please use the password you set during registration to log in.
`;
    }

    emailText += `
If you forgot your password, please use the password reset option.

Thank you,
Fingerprint MIS Team`;

    const mailOptions = {
      from: 'Fingerprint Attendance <eg8217178@gmail.com>',
      to: email,
      subject: 'Welcome to Fingerprint MIS - Your Login Details',
      text: emailText,
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log('Welcome email sent to:', email);
    } catch (error) {
      console.error('Error sending welcome email:', error);
    }
  });

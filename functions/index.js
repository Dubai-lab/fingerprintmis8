const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Gmail transporter
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'eg8217178@gmail.com', // your Gmail
    pass: 'maegdifdalucijey',    // your App Password
  },
});

exports.sendWelcomeEmail = functions.firestore
  .document('{collectionId}/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    const email = userData.email;
    const collectionId = context.params.collectionId;

    // Only send email for these collections
    if (!['instructors', 'security', 'invigilators'].includes(collectionId)) {
      console.log('Document created in collection', collectionId, '- no email sent.');
      return null;
    }

    // Ensure we have the actual password stored in Firestore
    const defaultPassword = typeof userData.defaultPassword === 'string' ? userData.defaultPassword : null;

    if (!defaultPassword) {
      console.log('No password found for user, skipping email.');
      return null;
    }

    // Plain text fallback
    const emailText = `Hello,

Your Fingerprint MIS account has been created.

Login details:
Email: ${email}
Temporary Password: ${defaultPassword}

Please log in and change your password immediately.

Thank you,
Fingerprint MIS Team
`;

    // HTML template
    const emailHtml = `
    <div style="font-family: Arial, sans-serif; background-color: #f6f6f6; padding: 20px;">
      <div style="max-width: 600px; margin: auto; background: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 8px rgba(0,0,0,0.1);">
        <div style="background-color: #4a148c; padding: 20px; text-align: center; color: #ffffff;">
          <h1 style="margin: 0;">Fingerprint MIS</h1>
          <p style="margin: 0;">UNILAK Attendance & Management System</p>
        </div>
        <div style="padding: 20px; color: #333333;">
          <h2>Welcome!</h2>
          <p>Your account has been successfully created in the Fingerprint Management Information System.</p>
          
          <h3>Login Details</h3>
          <p><strong>Email:</strong> ${email}</p>
          <p><strong>Temporary Password:</strong> ${defaultPassword}</p>

          <p style="color: #d32f2f; font-weight: bold;">Please change your password within 24 hours after your first login.</p>

          <p>If you forget your password, you can use the password reset option on the login page.</p>
          
          <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
          <p style="font-size: 14px; color: #555555; text-align: center;">
            Thank you,<br>
            <strong>Fingerprint MIS Team</strong>
          </p>
        </div>
      </div>
    </div>
    `;

    const mailOptions = {
      from: 'Fingerprint MIS <eg8217178@gmail.com>',
      to: email,
      subject: 'Welcome to Fingerprint MIS - Your Login Details',
      text: emailText,
      html: emailHtml,
    };

    try {
      const info = await transporter.sendMail(mailOptions);
      console.log('Welcome email sent:', info);
    } catch (error) {
      console.error('Error sending welcome email:', error);
    }
  });

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

// Custom Password Reset Email Function
exports.sendPasswordResetEmail = functions.https.onCall(async (data, context) => {
  const { email, resetLink } = data;

  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }

  // HTML template for password reset
  const emailHtml = `
  <div style="font-family: Arial, sans-serif; background-color: #f6f6f6; padding: 20px;">
    <div style="max-width: 600px; margin: auto; background: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 8px rgba(0,0,0,0.1);">
      <div style="background-color: #2563eb; padding: 20px; text-align: center; color: #ffffff;">
        <h1 style="margin: 0;">Fingerprint MIS</h1>
        <p style="margin: 0;">Password Reset Request</p>
      </div>
      <div style="padding: 20px; color: #333333;">
        <h2>Reset Your Password</h2>
        <p>We received a request to reset your password. Click the button below to create a new password.</p>
        
        <div style="margin: 30px 0; text-align: center;">
          <a href="${resetLink}" style="background-color: #2563eb; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold;">
            Reset Password
          </a>
        </div>

        <p style="color: #666666; font-size: 14px;">
          Or copy and paste this link in your browser:<br>
          <code style="background-color: #f3f4f6; padding: 8px; border-radius: 4px; word-break: break-all;">${resetLink}</code>
        </p>

        <p style="color: #d32f2f; margin: 20px 0;">
          <strong>⚠️ This link expires in 1 hour.</strong>
        </p>

        <p style="color: #666666; font-size: 13px;">
          If you didn't request a password reset, please ignore this email or contact support.
        </p>
        
        <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
        <p style="font-size: 12px; color: #999999; text-align: center;">
          Fingerprint MIS - UNILAK Attendance & Management System<br>
          <strong>Fingerprint MIS Team</strong>
        </p>
      </div>
    </div>
  </div>
  `;

  // Plain text fallback
  const emailText = `Hello,

You requested to reset your password. Click the link below to create a new password:

${resetLink}

This link expires in 1 hour.

If you didn't request this, please ignore this email.

Thank you,
Fingerprint MIS Team
`;

  const mailOptions = {
    from: 'Fingerprint MIS <eg8217178@gmail.com>',
    to: email,
    subject: 'Reset Your Fingerprint MIS Password',
    text: emailText,
    html: emailHtml,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log('Password reset email sent to:', email);
    return { success: true, message: 'Password reset email sent successfully' };
  } catch (error) {
    console.error('Error sending password reset email:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send password reset email');
  }
});

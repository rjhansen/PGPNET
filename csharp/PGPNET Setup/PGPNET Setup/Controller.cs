using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using System.Windows;
using System.Threading.Tasks;

namespace PGPNET_Setup
{
    static class Controller
    {
        static string gnupgPath = String.Empty;
        static string prrPath = String.Empty;
        public static string GnuPGPath
        {
            get
            {
                if (String.Empty != gnupgPath) return gnupgPath;

                try
                {
                    using (var registryKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"Software\GnuPG"))
                    {
                        gnupgPath = (String)registryKey.GetValue("Install Directory") + @"\bin\gpg.exe";
                        if (File.Exists(gnupgPath)) return gnupgPath;
                    }
                }
                catch
                {
                }
                MessageBox.Show("GnuPG could not be found.  Please check your installation.", "GnuPG Not Found", MessageBoxButton.OK);
                Application.Current.Shutdown();
                return null;
            }
        }

        public static string PRRPath
        {
            get
            {
                if (String.Empty != prrPath) return prrPath;

                var profileDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Thunderbird", "Profiles");

                if (!Directory.Exists(profileDir))
                {
                    MessageBox.Show("Could not find Thunderbird profile folder.", "File not found", MessageBoxButton.OK);
                    Application.Current.Shutdown();
                }

                string[] subdirs = (from dirname in Directory.GetDirectories(profileDir)
                                    where dirname.EndsWith(".default", StringComparison.CurrentCulture)
                                    select dirname).ToArray();
                if (subdirs.Length == 0)
                {
                    MessageBox.Show("Could not find any profiles in your Thunderbird folder.", "Profile not found", MessageBoxButton.OK);
                    Application.Current.Shutdown();
                }
                if (subdirs.Length > 1)
                {
                    MessageBox.Show("Multiple profiles found.  This application can't handle that — yet.", "Too many profiles", MessageBoxButton.OK);
                    Application.Current.Shutdown();
                }

                profileDir = subdirs[0];

                if (!File.Exists(Path.Combine(profileDir, "pgprules.xml")))
                {
                    MessageBox.Show("No Enigmail per-recipient rules in your profile.", "No pgprules.xml", MessageBoxButton.OK);
                    Application.Current.Shutdown();
                }
                prrPath = Path.Combine(profileDir, "pgprules.xml");
                return prrPath;
            }
        }

        public static void AdjustGPGConf()
        {
            var gpgconf = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "GnuPG", "gpg.conf");
            List<String> lines = null;
            try
            {
                using (var fh = File.OpenText(gpgconf))
                {
                    lines = (from line in fh.ReadToEnd().Split('\n')
                             where (!line.Trim().StartsWith("personal-") && line.Trim().Count() > 0)
                             select line.Trim()).ToList();
                }

                lines.Add("personal-cipher-preferences AES256 CAMELLIA256 TWOFISH AES192 CAMELLIA192 AES CAMELLIA128 CAST5");
                lines.Add("personal-digest-preferences SHA512 SHA384 SHA256 SHA224 RIPEMD160");
                lines.Add("personal-compress-preferences BZIP2 ZIP ZLIB");

                using (var fh = File.CreateText(gpgconf))
                {
                    foreach (var line in lines)
                        fh.WriteLine(line);
                }
            }
            catch
            {
                MessageBox.Show("Could not configure your GnuPG installation", "Error", MessageBoxButton.OK);
                Application.Current.Shutdown();
            }
        }
    }
}

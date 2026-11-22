import SwiftUI

struct LegalView: View {
    var body: some View {
        List {
            section("Community Terms", "By publishing on Artist Folio, you confirm that you own or have the rights to your work. There is no tolerance for objectionable content or abusive users, including sexual exploitation, hate, harassment, threats, scams, or stolen work.")
            section("Moderation", "Anyone can report an artwork or artist and block an artist. Reports are reviewed within 24 hours. Violating content is removed and repeat offenders lose access.")
            section("Purchases", "Artist Folio does not process payments, shipping, or returns. Any transaction is arranged directly between the artist and the collector, at their own risk.")
            section("Privacy", "Your profile, artworks, and any contact details you choose to add are public. Saved art, followed artists, and blocked artists stay in your private iCloud database. Artist Folio does not track you or sell your data.")
            section("Deleting Your Account", "You can delete your account from Profile at any time. This permanently removes your profile, artworks, and private library. Reports you submitted may be retained for safety review.")
        }
        .navigationTitle("Terms & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        Section(title) {
            Text(body).font(.subheadline)
        }
    }
}
